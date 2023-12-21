# IC design for Image Sharpening using Convolution
# 1.Perform the image transformation by mirroring  
The mirroring will be done vertically, relative to the image rows.

# 2. Compute the image equivalent in grayscale.
The resulting image will be stored in 8 bits in the 'G' channel. The value in the 'G' channel will be calculated as the average between the maximum and minimum values of the three channels. After this operation, the 'R' and 'B' channels will be set to the value '0'. The grayscale filter will be applied to the mirrored image.

# 3. Transform the grayscale image obtained in the previous step by applying a sharpness filter, using the convolution matrix: {-1; -1; -1; -1; 9; -1; -1; -1; -1}.
To calculate the value of the pixel at position [i, j], the 3×3 matrix surrounding this position is considered. Each element of this matrix is multiplied element-by-element with the convolution matrix (in the same way you would perform element-by-element multiplication in Matlab). The pixel at position [i, j] in the new image will be given by the sum of these 9 values.
---------------------------------------------------------------
# Implementation  details

1. **Pixel Selection Signals (row and col)**: These signals are used for both reading and writing operations. They select a pixel in the image at the specified (row, col) position. To read a pixel from the image that is to be processed (in_pix), the row and col signals must be set.

2. **Pixel Writing Signals**: To write a pixel into the processed image (out_pix), it's necessary to set the row and col signals, along with the out_we signal.

3. **Processing Completion Signals (*_done)**: These signals indicate the completion of image processing for each requested action. It's allowed to declare output types as reg for the process module. However, the inputs and outputs for the process and image modules should not be modified. Your modules will interact with the image module (already implemented in the skeleton of the task), which represents the image on which the transformations need to be applied.

4. **Pixel Size**: Each “pixel” in the image is 3 bytes in size, with 1 byte for each color channel.

5. **Edge Pixels in Image Filtering**: The images are bounded. When applying the filter on edge pixels, only the immediate neighboring pixels are considered. Anything outside the image boundary is treated as zero.

6. **Signal Maintenance (mirror_done, gray_done, filter_done)**: These signals must maintain a HIGH value for one clock cycle to be recognized by the tester. During this clock cycle, no other processing should be done, and the resolution of the next task should not begin.

------------------------------------------------------------------

The FSM is divided into a sequential part and a combinational part. State 0 is the reset state.

MIRROR PHASE:
The machine enters state 1 with row = 0 and col = 0. This pixel is saved in the variable aux_pixel1. The complementary element relative to the center of the matrix (63 - row) is determined. The machine then enters state 2 with row = 63 and col = 0. This pixel is saved in the variable aux_pixel2. In state 3, aux_pixel1 is written at position (63, 0). The row and column are reset to their original positions, after which aux_pixel2 is written in the matrix. New indices are determined by incrementing col until it reaches 63. When col reaches 63, it is reset to 0, and row is incremented. When row reaches (63 - 1)/2, the mirror algorithm ends and the flag is set to 1 in state 5.

GRAYSCALE PHASE:
The machine enters state 6 with row and col at zero. The minimum and maximum values among the pixels are calculated, and this value is saved in the variable min. The machine then moves to state 7, where writing occurs at position (0, 0). New indices are determined: col is incremented until it reaches 63. When col reaches 63, it is reset to 0, and row is incremented. When row reaches 63, the grayscale algorithm ends, and the flag is set to 1 in state 8.

SHARPNESS PHASE:
To apply the convolution matrix, three lines from the original image are saved (cached) in the buffer [7:0]aux_row[2:0][63:0]. Another buffer [7:0]sharp_array[63:0] is used to save the result of the element-by-element multiplication of the sharpness matrix and an image block. This method was chosen because the convolution matrix is applied to the original image, not the modified one. Therefore, writing the newly calculated elements is delayed.

The machine enters state 9, saving the first three lines of the original image. The index incrementation algorithm is similar to the first two stages. This state is for initializing the buffer and will not be revisited.

In state 10, the start and stop indices for the iterators are determined (thus ignoring elements outside the image). Two fixed-iteration for-loops are used, and indices are conditioned to be within the determined limits. sharp_sum is initialized to 9 times the center element. sharp_sum is a 32-bit signed variable (allowing for management of overflow and underflow). The two for-loops dictated by the previously determined indices are entered, and the remaining elements in the block are subtracted (excluding the central element and those outside). The final value is obtained and rounded to 255 if higher and 0 if lower. The result is saved in sharp_array at the current position. This state is used only once and will not be revisited.

State 11 involves writing the first calculated line sequentially.
State 12 performs the same calculations as state 10, but for the second line.
Starting from this state, a loop is created to automatically process the image lines.

In state 13, the previously calculated row is written.

State 14 involves shifting all elements in the image buffer up by one element.

In state 15, a new line is read into the last position of the buffer. The process returns to state 12, repeating the algorithm as long as row < 63. When row = 63, the last_row_flag is set to exit the loop and enter state 16.

=> 12 -> each element of line i (i = 1...63) is calculated
=> 13 -> the line is written; if row = 63, exit the loop of states
=> 14 -> the buffer is shifted up by one position
=> 15 -> a new element is read into the buffer
=> returns to 12

In states 16 and 17, the last line of the image, which is the last line in the buffer, is calculated and written. The method is identical to that used for the previous lines. Finally, the corresponding flag is set to one.

