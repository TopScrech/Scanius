enum ObjectCaptureMode {
    case object, area

    var title: String {
        self == .area ? "Area Capture" : "Object Capture"
    }
}
