from tensor import Tensor, TensorShape
from random import rand
from testing import assert_equal, assert_true, assert_almost_equal

from dainemo.utils.tensorutils import zero, fill, dot
from dainemo.utils.tensorutils import (
    elwise_transform,
    elwise_pow,
    elwise_op,
    batch_tensor_elwise_op,
)
from dainemo.utils.tensorutils import tsum, tmean, tstd, transpose_2D, transpose, pad_zeros

from math import sqrt, exp, round
from math import add, sub, mul, div

alias dtype = DType.float32
alias nelts: Int = simdwidthof[dtype]()


fn assert_tensors_equal(t1: Tensor[dtype], t2: Tensor[dtype], mode: String = "exact") raises:
    # Assert equal shapes
    assert_equal(t1.num_elements(), t2.num_elements())
    assert_equal(t1.rank(), t2.rank())
    for i in range(t1.rank()):
        assert_equal(t1.dim(i), t2.dim(i))
    # Assert equal values
    for i in range(t1.num_elements()):
        if mode == "exact":
            assert_equal(t1[i], t2[i])
        elif mode == "almost":
            assert_almost_equal[dtype, 1](t1[i], t2[i], relative_tolerance=1e-5)
        else:
            print("Mode must be 'exact' or 'almost'")


# <------------ZERO------------>
fn test_zero() raises:
    let A = Tensor[dtype](2, 3)
    var B = rand[dtype](2, 3)
    zero[dtype](B)
    assert_tensors_equal(A, B)


# <------------FILL------------>
fn test_fill() raises:
    var A = Tensor[dtype](2, 3)
    var B = Tensor[dtype](2, 3)
    for i in range(A.num_elements()):
        A[i] = 1.0
    fill[dtype, nelts](B, 1.0)
    assert_tensors_equal(A, B)


# <-------------DOT------------->
fn test_dot() raises:
    var A = Tensor[dtype](2, 3)
    var B = Tensor[dtype](3, 2)
    fill[dtype, nelts](A, 1.0)
    fill[dtype, nelts](B, 1.0)

    let C = dot[dtype, nelts](A, B)
    var C_expected = Tensor[dtype](2, 2)
    fill[dtype, nelts](C_expected, 3.0)
    assert_tensors_equal(C, C_expected)

    let D = dot[dtype, nelts](B, A)
    var D_expected = Tensor[dtype](3, 3)
    fill[dtype, nelts](D_expected, 2.0)
    assert_tensors_equal(D, D_expected)


# <-------------ELEMENT WISE TRANSFORM------------->
fn test_elwise_transform() raises:
    var A = Tensor[dtype](2, 10)
    var B = Tensor[dtype](2, 10)
    var C = Tensor[dtype](2, 10)
    var D = Tensor[dtype](2, 10)
    fill[dtype, nelts](A, 4)
    fill[dtype, nelts](B, 2)
    fill[dtype, nelts](C, exp[dtype, 1](2))
    fill[dtype, nelts](D, 7)

    A = elwise_transform[dtype, nelts, sqrt](A)
    assert_tensors_equal(A, B)

    B = elwise_transform[dtype, nelts, exp](B)
    assert_tensors_equal(B, C)

    C = elwise_transform[dtype, nelts, round](B)
    assert_tensors_equal(C, D)


# <-------------ELEMENT WISE POW of TENSOR OPERATORS------------->
fn test_elwise_pow() raises:
    var A = Tensor[dtype](1, 10)
    var B = Tensor[dtype](1, 10)
    for i in range(10):
        A[i] = i
        B[i] = i**2

    let C = elwise_pow[dtype, nelts](A, 2)
    assert_tensors_equal(B, C)


# <-------------ELEMENT WISE TENSOR-TENSOR OPERATORS------------->
fn test_elwise_tensor_tensor() raises:
    var t1 = Tensor[dtype](2, 10)
    var t2 = Tensor[dtype](2, 10)
    fill[dtype, nelts](t1, 3.0)
    fill[dtype, nelts](t2, 3.0)

    let result1 = elwise_op[dtype, nelts, add](t1, t2)
    var result1_expected = Tensor[dtype](2, 10)
    fill[dtype, nelts](result1_expected, 6.0)
    assert_tensors_equal(result1, result1_expected)

    let result2 = elwise_op[dtype, nelts, sub](t1, t2)
    let result2_expected = Tensor[dtype](2, 10)
    assert_tensors_equal(result2, result2_expected)

    let result3 = elwise_op[dtype, nelts, mul](t1, t2)
    var result3_expected = Tensor[dtype](2, 10)
    fill[dtype, nelts](result3_expected, 9.0)
    assert_tensors_equal(result3, result3_expected)

    let result4 = elwise_op[dtype, nelts, div](t1, t2)
    var result4_expected = Tensor[dtype](2, 10)
    fill[dtype, nelts](result4_expected, 1.0)
    assert_tensors_equal(result4, result4_expected)


# <-------------ELEMENT WISE TESNOR-SCALAR OPERATORS------------->
fn test_elwise_tensor_scalar() raises:
    let a: SIMD[dtype, 1] = 2.0
    var t1 = Tensor[dtype](2, 10)
    fill[dtype, nelts](t1, 1.0)

    let result1 = elwise_op[dtype, nelts, add](t1, a)
    var result1_expected = Tensor[dtype](2, 10)
    fill[dtype, nelts](result1_expected, 3.0)
    assert_tensors_equal(result1, result1_expected)

    let result2 = elwise_op[dtype, nelts, add](a, t1)
    assert_tensors_equal(result2, result1_expected)

    let result3 = elwise_op[dtype, nelts, sub](t1, a)
    var result3_expected = Tensor[dtype](2, 10)
    fill[dtype, nelts](result3_expected, -1)
    assert_tensors_equal(result3, result3_expected)

    let result4 = elwise_op[dtype, nelts, mul](a, t1)
    var result4_expected = Tensor[dtype](2, 10)
    fill[dtype, nelts](result4_expected, 2)
    assert_tensors_equal(result4, result4_expected)

    let result5 = elwise_op[dtype, nelts, div](t1, a)
    var result5_expected = Tensor[dtype](2, 10)
    fill[dtype, nelts](result5_expected, 0.5)
    assert_tensors_equal(result5, result5_expected)


# <-------------ELEMENT WISE BATCH-TENSOR OPERATORS------------->
fn test_elwise_batch_tensor() raises:
    var batch = Tensor[dtype](4, 10)
    for i in range(40):
        batch[i] = i
    # print(batch)

    var t = Tensor[dtype](10)
    for i in range(10):
        t[i] = -i
    # print(t)

    let batch_result1 = batch_tensor_elwise_op[dtype, nelts, add](batch, t)
    # print(batch_result1)

    let batch_result2 = batch_tensor_elwise_op[dtype, nelts, sub](batch, t)
    # print(batch_result2)

    let batch_result3 = batch_tensor_elwise_op[dtype, nelts, mul](batch, t)
    # print(batch_result3)


# <-------------SUM/MEAN/STD------------->
fn test_sum_mean_std() raises:
    var t = Tensor[dtype](2, 10)
    var s = 0
    for i in range(20):
        t[i] = i + 1
        s += i + 1

    # Not specifying the axis takes all elements regardless of the shape
    let tensor_sum = tsum[dtype, nelts](t)
    assert_equal(tensor_sum, s)

    let tensor_mean = tmean[dtype, nelts](t)
    assert_equal(tensor_mean, s / 20)

    let tensor_std = tstd[dtype, nelts](t)
    var expected_std: SIMD[dtype, 1] = 0
    for i in range(20):
        expected_std += (i + 1 - tensor_mean) ** 2
    expected_std = sqrt(expected_std / 20)
    assert_equal(tensor_std, expected_std)

    # When specifying the axis you can sum across batches
    let batch_sum_0 = tsum[dtype, nelts](t, axis=0)
    var expected_batch_sum_0 = Tensor[dtype](1, 10)
    for i in range(10):
        expected_batch_sum_0[i] = (i + 1) + (i + 1 + 10)
    assert_tensors_equal(batch_sum_0, expected_batch_sum_0)

    let batch_sum_1 = tsum[dtype, nelts](t, axis=1)
    var expected_batch_sum_1 = Tensor[dtype](2, 1)
    expected_batch_sum_1[0] = 1 + 2 + 3 + 4 + 5 + 6 + 7 + 8 + 9 + 10
    expected_batch_sum_1[1] = 11 + 12 + 13 + 14 + 15 + 16 + 17 + 18 + 19 + 20
    assert_tensors_equal(batch_sum_1, expected_batch_sum_1)

    # TODO: mean / std across a specified axis


# <-------------TRANSPOSE------------->
from test_tensorutils_data import TransposeData


fn test_transpose() raises:
    # Transpose 2D
    var data = TransposeData.generate_1_2dim_test_case()
    var transposed = transpose_2D[dtype, nelts](data.A)
    assert_tensors_equal(transposed, data.expected)

    # Transpose 2 dimensions
    data = TransposeData.generate_2_2dim_test_case()
    transposed = transpose[dtype, nelts](
        data.A, data.transpose_dims[0], data.transpose_dims[1]
    )
    assert_tensors_equal(transposed, data.expected)

    data = TransposeData.generate_3_2dim_test_case()
    transposed = transpose[dtype, nelts](
        data.A, data.transpose_dims[0], data.transpose_dims[1]
    )
    assert_tensors_equal(transposed, data.expected)

    data = TransposeData.generate_4_2dim_test_case()
    transposed = transpose[dtype, nelts](
        data.A, data.transpose_dims[0], data.transpose_dims[1]
    )
    assert_tensors_equal(transposed, data.expected)

    # Transpose all dimensions
    data = TransposeData.generate_1_alldim_test_case()
    var transpose_dims = DynamicVector[Int]()
    for i in range(len(data.transpose_dims)):
        transpose_dims.push_back(data.transpose_dims[i])

    transposed = transpose[dtype, nelts](data.A, transpose_dims)
    assert_tensors_equal(transposed, data.expected)

    # Transpose (reverse)
    data = TransposeData.generate_1_transpose_test_case()
    transposed = transpose[dtype, nelts](data.A)
    assert_tensors_equal(transposed, data.expected)


# <-------------FLATTEN/RESHAPE------------->
fn test_flatten() raises:
    var A = Tensor[dtype](2, 3)
    var B = Tensor[dtype](6)
    for i in range(6):
        A[i] = i + 1
        B[i] = i + 1

    var A_flat = A.reshape(
        TensorShape(A.num_elements())
    )  # or A.ireshape to modify in place
    assert_tensors_equal(A_flat, B)

    let A_resh = A_flat.reshape(A.shape())  # or A_flat.ireshape to modify in place
    assert_tensors_equal(A_resh, A)


# <-------------PADDING------------->
from test_tensorutils_data import PaddingData

fn test_padding() raises:
    # 1D padding (only after)
    var data = PaddingData.generate_1d_test_case_after()
    var padded_data = pad_zeros[dtype, nelts](data.A, data.pad_with)
    assert_tensors_equal(padded_data, data.expected)

    # 1D padding (before and after)
    data = PaddingData.generate_1d_test_case_before_after()
    padded_data = pad_zeros[dtype, nelts](data.A, data.pad_with)
    assert_tensors_equal(padded_data, data.expected)

    # 2D padding
    data = PaddingData.generate_2d_test_case()
    padded_data = pad_zeros[dtype, nelts](data.A, data.pad_with)
    assert_tensors_equal(padded_data, data.expected)

    # 3D padding (simple)
    data = PaddingData.generate_3d_test_case_simple()
    padded_data = pad_zeros[dtype, nelts](data.A, data.pad_with)
    assert_tensors_equal(padded_data, data.expected)

    # 3D padding
    data = PaddingData.generate_3d_test_case()
    padded_data = pad_zeros[dtype, nelts](data.A, data.pad_with)
    assert_tensors_equal(padded_data, data.expected)
    
    # 4D padding
    data = PaddingData.generate_4d_test_case()
    padded_data = pad_zeros[dtype, nelts](data.A, data.pad_with)
    assert_tensors_equal(padded_data, data.expected)

    

fn main():
    try:
        test_zero()
        test_fill()
        test_dot()
        test_elwise_transform()
        test_elwise_pow()
        test_elwise_tensor_tensor()
        test_elwise_tensor_scalar()
        test_elwise_batch_tensor()
        test_sum_mean_std()
        test_transpose()
        test_flatten()
        test_padding()
    except:
        print("[ERROR] Error in tensorutils.py")
