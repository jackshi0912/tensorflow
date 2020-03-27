// RUN: tf-opt %s -tf-layout-assignment -verify-diagnostics | FileCheck %s --dump-input=always

module attributes {
  tf.devices = {"/device:GPU:0" = {cc_major = 7 : i32, cc_minor = 0 : i32}}
} {

// CHECK-LABEL: func @transposeConv2D_3x3_f32
func @transposeConv2D_3x3_f32(%input: tensor<1x28x28x64xf32>, %filter: tensor<3x3x64x64xf32>) -> tensor<1x28x28x64xf32> {
  // cuDNN prefers NCHW data format for spatial convolutions.
  // CHECK: "tf.Conv2D"(%[[INPUT_TRANSPOSE:[0-9]*]], %arg1)
  // CHECK-SAME: data_format = "NCHW"
  %0 = "tf.Conv2D"(%input, %filter)
       {
         data_format = "NHWC",
         padding = "VALID",
         strides = [1, 1, 1, 1]
       } : (tensor<1x28x28x64xf32>, tensor<3x3x64x64xf32>)
        -> tensor<1x28x28x64xf32>

  return %0 : tensor<1x28x28x64xf32>
}

// CHECK-LABEL: func @transposeConv2D_1x1_f32
func @transposeConv2D_1x1_f32(%input: tensor<1x64x28x28xf32>, %filter: tensor<1x1x64x64xf32>) -> tensor<1x64x28x28xf32> {
  // 1x1 convolution can be computed as a GEMM in NHWC data format.
  // CHECK: "tf.Conv2D"(%[[INPUT_TRANSPOSE:[0-9]*]], %arg1)
  // CHECK-SAME: data_format = "NHWC"
  %0 = "tf.Conv2D"(%input, %filter)
       {
         data_format = "NCHW",
         padding = "VALID",
         strides = [1, 1, 1, 1]
       } : (tensor<1x64x28x28xf32>, tensor<1x1x64x64xf32>)
        -> tensor<1x64x28x28xf32>

  // Striding in spatial dimensions does not allow to use GEMM.
  // CHECK: "tf.Conv2D"(%arg0, %arg1)
  // CHECK-SAME: data_format = "NCHW"
  %1 = "tf.Conv2D"(%input, %filter)
       {
         data_format = "NCHW",
         padding = "VALID",
         strides = [1, 1, 2, 2]
       } : (tensor<1x64x28x28xf32>, tensor<1x1x64x64xf32>)
        -> tensor<1x64x14x14xf32>

  return %0 : tensor<1x64x28x28xf32>
}

// CHECK-LABEL: func @transposeConv2D_3x3_f16
func @transposeConv2D_3x3_f16(%input: tensor<1x64x28x28xf16>, %filter: tensor<3x3x64x64xf16>) -> tensor<1x64x28x28xf16> {
  // To use Tensor Cores for f16 data type, input must be in NHWC data format.
  // CHECK: "tf.Conv2D"(%[[INPUT_TRANSPOSE:[0-9]*]], %arg1)
  // CHECK-SAME: data_format = "NHWC"
  %0 = "tf.Conv2D"(%input, %filter)
       {
         data_format = "NCHW",
         padding = "VALID",
         strides = [1, 1, 1, 1]
       } : (tensor<1x64x28x28xf16>, tensor<3x3x64x64xf16>)
        -> tensor<1x64x28x28xf16>

  return %0 : tensor<1x64x28x28xf16>
}

// CHECK-LABEL: func @transposeConv2DBackpropFilter_f32
func @transposeConv2DBackpropFilter_f32(
  %input:        tensor<1x28x28x64xf32>,
  %filter_size:  tensor<4xi32>,
  %out_backprop: tensor<1x28x28x64xf32>
) -> tensor<1x1x64x64xf32> {

  // CHECK: "tf.Conv2DBackpropFilter"
  // CHECK-SAME: data_format = "NCHW"
  %0 = "tf.Conv2DBackpropFilter"(%input, %filter_size, %out_backprop)
       {
         data_format = "NHWC",
         padding = "VALID",
         strides = [1, 1, 1, 1]
       } : (tensor<1x28x28x64xf32>, tensor<4xi32>, tensor<1x28x28x64xf32>)
        -> tensor<1x1x64x64xf32>

  return %0 : tensor<1x1x64x64xf32>
}

// CHECK-LABEL: func @transposeConv2DBackpropFilter_f16
func @transposeConv2DBackpropFilter_f16(
  %input:        tensor<1x64x28x28xf16>,
  %filter_size:  tensor<4xi32>,
  %out_backprop: tensor<1x64x28x28xf16>
) -> tensor<1x1x64x64xf16> {

  // CHECK: "tf.Conv2DBackpropFilter"
  // CHECK-SAME: data_format = "NHWC"
  %0 = "tf.Conv2DBackpropFilter"(%input, %filter_size, %out_backprop)
       {
         data_format = "NCHW",
         padding = "VALID",
         strides = [1, 1, 1, 1]
       } : (tensor<1x64x28x28xf16>, tensor<4xi32>, tensor<1x64x28x28xf16>)
        -> tensor<1x1x64x64xf16>

  return %0 : tensor<1x1x64x64xf16>
}

// CHECK-LABEL: func @transposeConv2DBackpropInput_f32
func @transposeConv2DBackpropInput_f32(
  %input_size:   tensor<4xi32>,
  %filter:       tensor<1x28x28x64xf32>,
  %out_backprop: tensor<1x28x28x64xf32>
) -> tensor<1x28x28x64xf32> {

  // CHECK: "tf.Conv2DBackpropInput"
  // CHECK-SAME: data_format = "NCHW"
  %0 = "tf.Conv2DBackpropInput"(%input_size, %filter, %out_backprop)
       {
         data_format = "NHWC",
         padding = "VALID",
         strides = [1, 1, 1, 1]
       } : (tensor<4xi32>, tensor<1x28x28x64xf32>, tensor<1x28x28x64xf32>)
        -> tensor<1x28x28x64xf32>

  return %0 : tensor<1x28x28x64xf32>
}

// CHECK-LABEL: func @transposeConv2DBackpropInput_f16
func @transposeConv2DBackpropInput_f16(
  %input_size:   tensor<4xi32>,
  %filter:       tensor<1x64x28x28xf16>,
  %out_backprop: tensor<1x64x28x28xf16>
) -> tensor<1x64x28x28xf16> {

  // CHECK: "tf.Conv2DBackpropInput"
  // CHECK-SAME: data_format = "NHWC"
  %0 = "tf.Conv2DBackpropInput"(%input_size, %filter, %out_backprop)
       {
         data_format = "NCHW",
         padding = "VALID",
         strides = [1, 1, 1, 1]
       } : (tensor<4xi32>, tensor<1x64x28x28xf16>, tensor<1x64x28x28xf16>)
        -> tensor<1x64x28x28xf16>

  return %0 : tensor<1x64x28x28xf16>
}

}
