from tensor import Tensor
from utils.index import Index

from math import div
from dainemo.utils.tensorutils import elwise_op, tmean, tstd


struct BostonHousing[dtype: DType]:
    var data: Tensor[dtype]
    var labels: Tensor[dtype]

    fn __init__(inout self, file_path: String) raises:
        var s = read_file(file_path)
        s = s[find_first(s, "\n")+1:]       # Ignore header

        let N = num_lines(s)       
        self.data = Tensor[dtype](N, 13)        # All columns except the last one
        self.labels = Tensor[dtype](N, 1)       # Only the last column (MEDV), Always specify 1!

        let idx_low: Int
        let idx_high: Int
        var idx_line: Int = 0

        # Load data in Tensor   
        # TODO: redo when String .split(",") is supported
        for i in range(N):
            s = s[idx_line:]
            idx_line = find_first(s, "\n") + 1
            for n in range(13):
                idx_low = find_nth(s, ",", n) + 1
                idx_high = find_nth(s, ",", n + 1)
                
                self.data[Index(i, n)] = cast_string[dtype](s[idx_low:idx_high])

            idx_low = find_nth(s, ",", 13) + 1 
            self.labels[i] = cast_string[dtype](s[idx_low:idx_line-1])

        # Normalize data
        # TODO: redo when tensorutils tmean2 and tstd2 are implemented
        alias nelts = simdwidthof[dtype]()
        var col = Tensor[dtype](N)
        for j in range(13):
            for k in range(N):
                col[k] = self.data[Index(k, j)]
            for i in range(N):
                self.data[Index(i, j)] = (self.data[Index(i, j)] - tmean[dtype, nelts](col)) / tstd[dtype, nelts](col)
            


struct MNIST[dtype: DType]:
    var data: Tensor[dtype]
    var labels: Tensor[dtype]

    fn __init__(inout self, file_path: String) raises:
        var s = read_file(file_path)
        s = s[find_first(s, "\n")+1:]   # Ignore header

        let N = num_lines(s)                   
        self.data = Tensor[dtype](N, 1, 28, 28)
        self.labels = Tensor[dtype](N, 1)       # Always specify 1!

        let idx_low: Int
        let idx_high: Int
        var idx_line: Int = 0

        # Load data in Tensor   
        # TODO: redo when String .split(",") is supported
        for i in range(N):
            s = s[idx_line:]
            idx_line = find_first(s, "\n") + 1
            self.labels[i] = atol(s[:find_first(s, ",")])
            for m in range(28):
                for n in range(28):
                    idx_low = find_nth(s, ",", 28 * m + n + 1) + 1
                    if m == 27 and n == 27:
                        self.data[Index(i, 0, m, n)] = atol(s[idx_low:idx_line-1])
                    else:
                        idx_high = find_nth(s, ",", 28 * m + n + 2)
                        self.data[Index(i, 0, m, n)] = atol(s[idx_low:idx_high])

        # Normalize data
        self.data = elwise_op[dtype, simdwidthof[dtype](), div](self.data, 255.0)


fn read_file(file_path: String) raises -> String:
    let s: String
    with open(file_path, "r") as f:
        s = f.read()
    return s


fn num_lines(s: String) -> Int:
    var count: Int = 0
    for i in range(len(s)):
        if s[i] == "\n":
            count += 1
    return count


fn find_first(s: String, delimiter: String) -> Int:
    for i in range(len(s)):
        if s[i] == delimiter:
            return i
    return -1


fn find_nth(s: String, delimiter: String, n: Int) -> Int:
    var count: Int = 0
    if n == 0:
        return -1
    for i in range(len(s)):
        if s[i] == delimiter:
            count += 1
            if count == n:
                return i
    return -1


fn cast_string[dtype: DType](s: String) raises -> SIMD[dtype, 1]:
    '''
    Cast a string with decimal to a SIMD vector of dtype.
    '''
    
    let idx = find_first(s, delimiter=".")
    var x: SIMD[dtype, 1] = -1

    if idx == -1:
        # No decimal point
        x = atol(s)
        return x
    else:
        let c_int: SIMD[dtype, 1]
        let c_frac: SIMD[dtype, 1]
        c_int = atol(s[:idx])
        c_frac = atol(s[idx+1:])
        x = c_int + c_frac / (10 ** len(s[idx+1:]))
        return x