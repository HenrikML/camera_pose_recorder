# Create annotated reference data for object pose estimation
This app was created as a part of my master's thesis (link to thesis available later). The app was created from a template provided by apple available at: https://developer.apple.com/documentation/arkit/arkit_in_ios/content_anchors/scanning_and_detecting_3d_objects

## How to create a scan
1. In the main menu tap the 'scan' button.
2. Place a bounding box by tapping the 'next' button.
3. Resize and move the bounding box over the object you want to scan.
	- Move the bounding box along a plane by swiping one of the sides.
	- Scale a side by pressing and holding the side.
	- Rotate the bounding box by pinching the bounding box.
4. To start the scan, tap the 'scan' button
5. Scan the object from all sides. The progress should reach 100% to indicate a completed scan.
6. To finish the scan, press the 'finish' button.
7. The annotated scan is now saved in Files under '6DPoseEstimation/scan_YYYY-MM-DD_hh-mm-ss'
	- 'video.mov' contains the recorded video
	- 'bounding_box.txt' contains the length of each side of the bounding box (extent_x, extent_y, extent_z) and the transform matrix of it's center (m_ij).
	- 'cam_intrinsics.txt' contains the camera intrinsics for each frame.
	- 'cam_transform.txt' contains the camera transform matrix (extrinsic matrix) for each frame.
	- 'depth/depth_x.bin' contains the depth image recorded by the devices LiDAR sensor. The data is in a float32 matrix of size 256x192 and the values are in centimeters.