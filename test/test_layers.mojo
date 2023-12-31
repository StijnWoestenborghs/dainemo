from random import rand
from tensor import Tensor
from testing import assert_equal

import dainemo.nn as nn
from dainemo import GRAPH
from dainemo.autograd.node import Node

alias dtype = DType.float32


# <------------LINEAR------------>
fn test_linear() raises:
    var f = nn.Linear(5, 3)                             # 5 inputs, 3 outputs
    
    let inputs: Tensor[dtype] = rand[dtype](2, 5)       # A batch of 2 with 5 inputs
    
    let outputs = f(Node[dtype](inputs))                # Should be a batch of 2 with 3 outputs

    print("Input batch of 2 with 5 inputs:", inputs.shape())
    print("Output batch of 2 with 3 outputs:", outputs.tensor.shape())
    assert_equal(outputs.tensor.dim(0), 2)
    assert_equal(outputs.tensor.dim(1), 3)
    
    # 5 Nodes added to the graph
    # inputs, weights, output(inputsxweight), bias, output(output+bias)
    assert_equal(GRAPH.graph.size, 5)
    GRAPH.reset_all()


# <------------CONV2D------------>
fn test_conv2d() raises:   
    let f = nn.Conv2d[
        padding=2,
        stride=1
    ](
        in_channels=1,
        out_channels=1,
        kernel_size=(1, 16)
    )

    let inputs: Tensor[dtype] = rand[dtype](4, 1, 28, 28)
    
    let outputs = f(Node[dtype](inputs))

    print("Input batch of 4 with 1x28x28 inputs:", inputs.shape())
    print("Output batch of 4 with 1x32x17 outputs:", outputs.tensor.shape())
    assert_equal(outputs.tensor.dim(0), 4)
    assert_equal(outputs.tensor.dim(1), 1)
    assert_equal(outputs.tensor.dim(2), 32)
    assert_equal(outputs.tensor.dim(3), 17)

    # 4 Nodes added to the graph: inputs, weights, bias, outputs(conv2d)
    assert_equal(GRAPH.graph.size, 4)
    GRAPH.reset_all()


fn test_conv2d_b() raises:
    let f = nn.Conv2d[
        padding=0,
        stride=1
    ](
        in_channels=1,
        out_channels=1,
        kernel_size=2
    )

    let inputs: Tensor[dtype] = rand[dtype](4, 1, 32, 17)

    let outputs = f(Node[dtype](inputs))

    print("Input batch of 4 with 1x32x17 inputs:", inputs.shape())
    print("Output batch of 4 with 1x31x16 outputs:", outputs.tensor.shape())
    assert_equal(outputs.tensor.dim(0), 4)
    assert_equal(outputs.tensor.dim(1), 1)
    assert_equal(outputs.tensor.dim(2), 31)
    assert_equal(outputs.tensor.dim(3), 16)

    # 4 Nodes added to the graph: inputs, weights, bias, outputs(conv2d)
    assert_equal(GRAPH.graph.size, 4)
    GRAPH.reset_all()


fn main():

    try:
        test_linear()
        test_conv2d()
        test_conv2d_b()
    except:
        print("[ERROR] Error in layers")
