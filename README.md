![ScaleVideo](http://www.limit-point.com/assets/images/ScaleVideo.jpg)
# ScaleVideo.swift
## Scales video in time domain

Learn more about scaling video from our [in-depth blog post](https://www.limit-point.com/blog/2022/scale-video).

The associated Xcode project implements a [SwiftUI] app for macOS and iOS that imports from Files, scales and exports to Files.

Select the scale factor from a slider.

## Classes

The project is comprised of:

1. The [App] (`ScaleVideoApp`) for import, scale and export.
2. And an [ObservableObject] (`ScaleVideoObservable`) that manages the user interaction to scale and play video files.
3. The [AVFoundation] and [vDSP] code (`ScaleVideo`) that reads, scales and writes video files.

### ScaleVideoApp

Videos to scale are imported from Files using [fileImporter] and exported to Files using [fileExporter]

### ScaleVideoObservable

To facilitate exporting using `fileExporter` a [FileDocument] named `VideoDocument` is prepared with a [FileWrapper] created from the [URL] of the scaled video.

### ScaleVideo

Scaling video is performed using [AVFoundation] and [vDSP].

The ScaleVideo initializer `init`:

```swift
init?(path: String, desiredDuration: Float64, frameRate: Int32, destination: String, progress: @escaping (CGFloat, CIImage?) -> Void, completion: @escaping (URL?, String?) -> Void)
```

Arguments:

1. **path: String** - The path of the video file to be scaled.

2. **desiredDuration: Float64** - The desired duration in seconds of the scaled video. 

3. **frameRate: Int32** - The desired frame rate of the scaled video. 

4. **destination: String** - The path of the scaled video file.

5. **progress** - A handler that is periodically executed to send progress images and values.

6. **completion** - A handler that is executed when the operation has completed to send a message of success or not.

Example usage is provided in the code: 

```swift
func testScaleVideo() {
    let fm = FileManager.default
    let docsurl = try! fm.url(for:.documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
    
    let destinationPath = docsurl.appendingPathComponent("DefaultVideoScaled.mov").path
    let scaleVideo = ScaleVideo(path: kDefaultURL.path, desiredDuration: 8, frameRate: 30, destination: destinationPath) { p, _ in
        print("p = \(p)")
    } completion: { result, error in
        print("result = \(String(describing: result))")
    }
    
    scaleVideo?.start()
}
```

[App]: https://developer.apple.com/documentation/swiftui/app
[ObservableObject]: https://developer.apple.com/documentation/combine/observableobject
[AVFoundation]: https://developer.apple.com/documentation/avfoundation/
[vDSP]: https://developer.apple.com/documentation/accelerate/vdsp
[SwiftUI]: https://developer.apple.com/tutorials/swiftui
[fileImporter]: https://developer.apple.com/documentation/swiftui/form/fileimporter(ispresented:allowedcontenttypes:allowsmultipleselection:oncompletion:)
[fileExporter]: https://developer.apple.com/documentation/swiftui/form/fileexporter(ispresented:document:contenttype:defaultfilename:oncompletion:)-1srj
[FileDocument]: https://developer.apple.com/documentation/swiftui/filedocument
[FileWrapper]: https://developer.apple.com/documentation/foundation/filewrapper
[URL]: https://developer.apple.com/documentation/foundation/url
