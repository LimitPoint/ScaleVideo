![ScaleVideo](http://www.limit-point.com/assets/images/ScaleVideo.jpg)
# ScaleVideo.swift
## Scales video in time domain

The associated Xcode project implements a [SwiftUI] app for macOS and iOS that scales video files stored on your device or iCloud. 

A default video file is provided to set the initial state of the app. 

After a video is imported it is displayed in the [VideoPlayer] where it can be viewed, along with its scaled counterpart.

Select the scale factor from a slider.

## Classes

The project is comprised of:

1. `ScaleVideoApp` - The [App] for import, scale and export.
2. `ScaleVideoObservable` - An [ObservableObject] that manages the user interaction to scale and play video files.
3. `ScaleVideo` - The [AVFoundation] and [vDSP] code that reads, scales and writes video files.

### ScaleVideoApp

Videos to scale are imported from Files using [fileImporter] and exported to Files using [fileExporter]. 

The scaling is monitored with a [ProgressView].

The video and scaled video can be played with a [VideoPlayer].

### ScaleVideoObservable

Creates the `ScaleAudio` object to perform the scaling operation and send progress back to the app.

The `URL` of the video to scale is received from the file import operation and, if needed, downloaded with [startDownloadingUbiquitousItem] or security accessed with [startAccessingSecurityScopedResource].

To facilitate exporting using `fileExporter` a [FileDocument] named `VideoDocument` is prepared with a [FileWrapper] created from the [URL] of the scaled video.

### ScaleVideo

Scaling video is performed using [AVFoundation] and [vDSP].

The ScaleVideo initializer `init`:

```swift
init?(path : String, desiredDuration: Float64, frameRate: Int32, destination: String, progress: @escaping (CGFloat, CIImage?) -> Void, completion: @escaping (URL?, String?) -> Void)
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
    let scaleVideo = ScaleVideo(path: kDefaultURL.path, desiredDuration: 8, frameRate: 30, expedited: false, destination: destinationPath) { p, _ in
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
[VideoPlayer]: https://developer.apple.com/documentation/avkit/videoplayer
[ProgressView]: https://developer.apple.com/documentation/swiftui/progressview
[startDownloadingUbiquitousItem]: https://developer.apple.com/documentation/foundation/filemanager/1410377-startdownloadingubiquitousitem
[startAccessingSecurityScopedResource]: https://developer.apple.com/documentation/foundation/nsurl/1417051-startaccessingsecurityscopedreso
