from tensor import Tensor, TensorShape
from utils.index import Index
from algorithm import vectorize, parallelize
from memory import memset_zero

from math import sqrt, pow, equal, max, min


@always_inline
fn zero[dtype: DType](inout t: Tensor[dtype]):
    memset_zero[dtype](t.data(), t.num_elements())


@always_inline
fn fill[dtype: DType, nelts: Int](inout t: Tensor[dtype], val: SIMD[dtype, 1]):
    @parameter
    fn fill_vec[nelts: Int](idx: Int):
        t.simd_store[nelts](idx, t.simd_load[nelts](idx).splat(val))

    vectorize[nelts, fill_vec](t.num_elements())


@always_inline
fn elwise_transform[
    dtype: DType,
    nelts: Int,
    func: fn[dtype: DType, nelts: Int] (x: SIMD[dtype, nelts]) -> SIMD[dtype, nelts],
](t: Tensor[dtype]) -> Tensor[dtype]:
    var t_new = Tensor[dtype](t.shape())

    @parameter
    fn vecmath[nelts: Int](idx: Int):
        t_new.simd_store[nelts](idx, func[dtype, nelts](t.simd_load[nelts](idx)))

    vectorize[nelts, vecmath](t.num_elements())
    return t_new


@always_inline
fn elwise_pow[dtype: DType, nelts: Int](t: Tensor[dtype], x: Int) -> Tensor[dtype]:
    var t_new = Tensor[dtype](t.shape())

    @parameter
    fn vecpow[nelts: Int](idx: Int):
        t_new.simd_store[nelts](idx, pow(t.simd_load[nelts](idx), x))

    vectorize[nelts, vecpow](t.num_elements())
    return t_new


@always_inline
fn elwise_op[
    dtype: DType,
    nelts: Int,
    func: fn[dtype: DType, nelts: Int] (
        x: SIMD[dtype, nelts], y: SIMD[dtype, nelts]
    ) -> SIMD[dtype, nelts],
](t1: Tensor[dtype], t2: Tensor[dtype]) -> Tensor[dtype]:
    """Element-wise operation on two tensors."""
    var t_new = Tensor[dtype](t1.shape())

    @parameter
    fn vecmath[nelts: Int](idx: Int):
        t_new.simd_store[nelts](
            idx, func[dtype, nelts](t1.simd_load[nelts](idx), t2.simd_load[nelts](idx))
        )

    vectorize[nelts, vecmath](t1.num_elements())
    return t_new


@always_inline
fn elwise_op[
    dtype: DType,
    nelts: Int,
    func: fn[dtype: DType, nelts: Int] (
        x: SIMD[dtype, nelts], y: SIMD[dtype, nelts]
    ) -> SIMD[dtype, nelts],
](t1: Tensor[dtype], a: SIMD[dtype, 1]) -> Tensor[dtype]:
    """Element-wise operation on a tensor and a scalar."""
    var t_new = Tensor[dtype](t1.shape())

    @parameter
    fn vecmath[nelts: Int](idx: Int):
        t_new.simd_store[nelts](idx, func[dtype, nelts](t1.simd_load[nelts](idx), a))

    vectorize[nelts, vecmath](t1.num_elements())
    return t_new


@always_inline
fn elwise_op[
    dtype: DType,
    nelts: Int,
    func: fn[dtype: DType, nelts: Int] (
        x: SIMD[dtype, nelts], y: SIMD[dtype, nelts]
    ) -> SIMD[dtype, nelts],
](a: SIMD[dtype, 1], t1: Tensor[dtype]) -> Tensor[dtype]:
    """Element-wise operation on a tensor and a scalar."""
    var t_new = Tensor[dtype](t1.shape())

    @parameter
    fn vecmath[nelts: Int](idx: Int):
        t_new.simd_store[nelts](idx, func[dtype, nelts](a, t1.simd_load[nelts](idx)))

    vectorize[nelts, vecmath](t1.num_elements())
    return t_new


@always_inline
fn batch_tensor_elwise_op[
    dtype: DType,
    nelts: Int,
    func: fn[dtype: DType, nelts: Int] (
        x: SIMD[dtype, nelts], y: SIMD[dtype, nelts]
    ) -> SIMD[dtype, nelts],
](t_batch: Tensor[dtype], t2: Tensor[dtype]) -> Tensor[dtype]:
    """Element-wise operation on between a batch of tensors t_batch and a tensor t2."""
    var t_new = Tensor[dtype](t_batch.shape())

    @parameter
    fn row_op(r: Int):
        @parameter
        fn vecmath[nelts: Int](c: Int):
            t_new.simd_store[nelts](
                r * t_batch.dim(1) + c,
                func[dtype, nelts](
                    t_batch.simd_load[nelts](r * t_batch.dim(1) + c),
                    t2.simd_load[nelts](c),
                ),
            )

        vectorize[nelts, vecmath](t_batch.dim(1))

    parallelize[row_op](t_batch.dim(0), t_batch.dim(0))
    return t_new


@always_inline
fn tsum[dtype: DType, nelts: Int](t: Tensor[dtype]) -> SIMD[dtype, 1]:
    var s: SIMD[dtype, 1] = 0

    @parameter
    fn vecsum[nelts: Int](idx: Int):
        s += t.simd_load[nelts](idx).reduce_add()

    vectorize[nelts, vecsum](t.num_elements())
    return s


# from testing import assert_equal
@always_inline
fn tsum[dtype: DType, nelts: Int](t: Tensor[dtype], axis: Int) -> Tensor[dtype]:
    let d: Int = 1 if axis == 0 else 0
    let t_new = Tensor[dtype](1, t.dim(d)) if axis == 0 else Tensor[dtype](t.dim(d), 1)

    @parameter
    fn parallel_sum(i: Int):
        var s: SIMD[dtype, 1] = 0

        @parameter
        fn axissum[nelts: Int](j: Int):
            let index = j * t.dim(d) + i if axis == 0 else i * t.dim(axis) + j
            s += t.simd_load[nelts](index).reduce_add()

        vectorize[nelts, axissum](t.dim(axis))
        t_new[i] = s

    parallelize[parallel_sum](t.dim(d), t.dim(d))

    return t_new


@always_inline
fn tmean[dtype: DType, nelts: Int](t: Tensor[dtype]) -> SIMD[dtype, 1]:
    return tsum[dtype, nelts](t) / t.num_elements()


@always_inline
fn tstd[dtype: DType, nelts: Int](t: Tensor[dtype]) -> SIMD[dtype, 1]:
    var mu: SIMD[dtype, 1] = tmean[dtype, nelts](t)
    var variance: SIMD[dtype, 1] = 0

    @parameter
    fn vecvar[nelts: Int](idx: Int):
        let diff = t.simd_load[nelts](idx) - mu
        variance += (diff * diff).reduce_add()

    vectorize[nelts, vecvar](t.num_elements())

    return sqrt(variance / t.num_elements())


fn tmean2[dtype: DType](t: Tensor[dtype], axis: Int = 0):
    """Calculate mean of a 2D tensor along a specified axis."""
    # TODO: every mean of vector can be calulated in parallel where each mean calculation can be vectorized
    pass


fn tstd2[dtype: DType](t: Tensor[dtype], axis: Int = 0):
    """Calculate standard deviation of a 2D tensor along a specified axis."""
    # TODO
    pass


@always_inline
fn dot[dtype: DType, nelts: Int](A: Tensor[dtype], B: Tensor[dtype]) -> Tensor[dtype]:
    var C = Tensor[dtype](A.dim(0), B.dim(1))
    memset_zero[dtype](C.data(), C.num_elements())

    @parameter
    fn calc_row(m: Int):
        for k in range(
            B.dim(0)
        ):  # TODO: test dot(4x1x28x28, 784x32) = (4x32) // mnist case

            @parameter
            fn dot[nelts: Int](n: Int):
                C.simd_store[nelts](
                    m * C.dim(1) + n,
                    C.simd_load[nelts](m * C.dim(1) + n)
                    + A[m, k] * B.simd_load[nelts](k * B.dim(1) + n),
                )

            vectorize[nelts, dot](C.dim(1))

    parallelize[calc_row](C.dim(0), C.dim(0))

    return C


@always_inline
fn transpose_2D[dtype: DType, nelts: Int](t: Tensor[dtype]) -> Tensor[dtype]:
    # NOTE: This function could be deleted to use instead the transpose function
    var t_new = Tensor[dtype](t.dim(1), t.dim(0))

    let stride = t.dim(0)

    @parameter
    fn proc_row(i: Int):
        @parameter
        fn proc_column[nelts: Int](j: Int):
            t_new.data().offset(j * t.dim(0) + i).simd_strided_store[nelts](
                t.simd_load[nelts](i * t.dim(1) + j), stride
            )

        vectorize[nelts, proc_column](t.dim(1))

    parallelize[proc_row](t.dim(0))

    return t_new


@always_inline
fn calculate_strides(shape: TensorShape) -> DynamicVector[Int]:
    var strides = DynamicVector[Int](shape.rank())
    strides.resize(shape.rank(), 1)

    for i in range(shape.rank() - 2, -1, -1):
        strides[i] = strides[i + 1] * shape[i + 1]

    return strides


@always_inline
fn transpose[
    dtype: DType, nelts: Int
](t: Tensor[dtype], dim_0: Int, dim_1: Int) -> Tensor[dtype]:
    """
    Create a new tensor transposing dim_0 and dim_1.
    """
    var axes = DynamicVector[Int](t.rank())

    for i in range(t.rank()):
        if i == dim_0:
            axes.push_back(dim_1)
        elif i == dim_1:
            axes.push_back(dim_0)
        else:
            axes.push_back(i)

    return transpose[dtype, nelts](t, axes)


@always_inline
fn transpose[dtype: DType, nelts: Int](t: Tensor[dtype]) -> Tensor[dtype]:
    """
    Create a new transposed tensor of the given tensor t.
    """
    var axes = DynamicVector[Int](t.rank())

    for i in range(t.rank() - 1, -1, -1):
        axes.push_back(i)

    return transpose[dtype, nelts](t, axes)


# It would be better to use VariadiList for axes, but because variadiclist can't be modified it wouldn't be possible to use overloaded transpose functions
@always_inline
fn transpose[
    dtype: DType, nelts: Int
](t: Tensor[dtype], axes: DynamicVector[Int]) -> Tensor[dtype]:
    """
    Create a new transposed tensor of the given tensor t.
    """
    # NOTE: The rank of of the t tensor should be 2 or more
    # NOTE: Axes should be the same size as the rank of t
    var new_shape = DynamicVector[Int](t.rank())
    for i in range(t.rank()):
        new_shape.push_back(t.dim(axes[i]))
    var t_new = Tensor[dtype](new_shape)

    let original_strides = calculate_strides(t.shape())
    let transposed_strides = calculate_strides(t_new.shape())

    # NOTE: The reason why we use original_strides_shape and
    # transposed_strides_shape is because it seems there is a *bug* when using
    # dynamic vectors inside a parameter function? or a parameter function that
    # is used in parallelized. If we use the dynamic vector inside the
    # parallelized function, the memory of the dynamic vector is not initialized.
    let original_strides_shape = TensorShape(original_strides)
    let transposed_strides_shape = TensorShape(transposed_strides)

    @parameter
    fn p_transpose(i: Int):
        var new_index = 0
        var linear_index = i
        for j in range(t.rank()):
            let stride = original_strides_shape[j]
            let index = linear_index // stride
            linear_index = linear_index % stride

            new_index += index * transposed_strides_shape[axes[j]]

        t_new[new_index] = t[i]

        @parameter
        fn v_transpose[nelts: Int](j: Int):
            var new_index = 0
            let original_index = i * t.dim(t.rank() - 1) + j
            var linear_index = original_index
            for k in range(t.rank()):
                let stride = original_strides_shape[k]
                let index = linear_index // stride
                linear_index = linear_index % stride

                new_index += index * transposed_strides_shape[axes[k]]

            t_new.data().offset(new_index).simd_strided_store[nelts](
                t.simd_load[nelts](original_index),
                transposed_strides_shape[axes[t.rank() - 1]],
            )

        vectorize[nelts, v_transpose](t.dim(t.rank() - 1))

    parallelize[p_transpose](t.num_elements() // t.dim(t.rank() - 1))

    return t_new


# TODO: Deprecate this function, as it is not used anymore
@always_inline
fn pad_zeros[
    dtype: DType, nelts: Int
](t: Tensor[dtype], pad_with: DynamicVector[Int]) -> Tensor[dtype]:
    """
    Pad a tensor with zeros along the specified axes of an N dimensional tensor.
    Number of values padded to the edges of each axis.
    Example: ((before_1, after_1), ... (before_N, after_N)).
    """
    
    # NOTE: The rank of of the t tensor should be equal to the size of pad_with devided by 2.
    # As pad_with contains (before, after) number of paddings for each axis.
    var new_shape = DynamicVector[Int](t.rank())
    for i in range(t.rank()):
        new_shape.push_back(t.dim(i) + pad_with[i * 2] + pad_with[i * 2 + 1])
    var t_new = Tensor[dtype](new_shape)

    let original_strides = calculate_strides(t.shape())
    let result_strides = calculate_strides(t_new.shape())

    # NOTE: The reason why we use original_strides_shape and
    # transposed_strides_shape is because it seems there is a *bug* when using
    # dynamic vectors inside a parameter function? or a parameter function that
    # is used in parallelized. If we use the dynamic vector inside the
    # parallelized function, the memory of the dynamic vector is not initialized.
    let original_strides_shape = TensorShape(original_strides)
    let result_strides_shape = TensorShape(result_strides)

    # Parallelize over the first axis
    # NOTE: Possible dynamically choose the axis to parallelize over

    @parameter
    fn p_pad(i: Int):
        
        for j in range(t.num_elements() // t.dim(0)):

            let original_index = i * original_strides_shape[0] + j
            
            # Padding contribution of the first dimention
            var dest_index = (i + pad_with[0]) * result_strides_shape[0]
            
            # Calculate the contribution from each dimension
            var remaining_index = j % original_strides_shape[0]
            for dim in range(1, t.rank()):
                let stride = original_strides_shape[dim]
                let index = remaining_index // stride
                remaining_index = remaining_index % stride

                dest_index += (index + pad_with[dim * 2]) * result_strides_shape[dim]
            
            # TODO: figure out vectorization
            t_new[dest_index] = t[original_index]

    parallelize[p_pad](t.dim(0))

    return t_new