import UIKit
import AVFoundation

protocol ScanViewControllerDelegate: AnyObject {
  func scanViewController(_ controller: ScanViewController, didScan code: String)
}

class ScanViewController: UIViewController {
  private var captureSession = AVCaptureSession()
  private var videoPreviewLayer: AVCaptureVideoPreviewLayer?
  weak var delegate: ScanViewControllerDelegate?
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    switch AVCaptureDevice.authorizationStatus(for: .video) {
    case .authorized:
        setupCamera()
    case .notDetermined:
        AVCaptureDevice.requestAccess(for: .video) { granted in
            if granted {
                DispatchQueue.main.async {
                    self.setupCamera()
                }
            }
        }
    default:
        print("Camera access denied")
        dismiss(animated: true, completion: nil)
        return
    }
  }

  private func setupCamera() {
    let deviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInDualCamera, .builtInWideAngleCamera], mediaType: .video, position: .back)
    
    guard let captureDevice = deviceDiscoverySession.devices.first else {
        print("Failed to get the camera device")
        dismiss(animated: true, completion: nil)
        return
    }
    
    do {
        let input = try AVCaptureDeviceInput(device: captureDevice)
        captureSession.addInput(input)
        let captureMetadataOutput = AVCaptureMetadataOutput()
        captureSession.addOutput(captureMetadataOutput)
        captureMetadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
        captureMetadataOutput.metadataObjectTypes = [AVMetadataObject.ObjectType.qr]
    } catch {
        print(error)
        dismiss(animated: true, completion: nil)
        return
    }
    
    videoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
    videoPreviewLayer?.videoGravity = AVLayerVideoGravity.resizeAspectFill
    videoPreviewLayer?.frame = view.layer.bounds
    view.layer.addSublayer(videoPreviewLayer!)
    
    captureSession.startRunning()
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    if !captureSession.isRunning {
        captureSession.startRunning()
    }
  }

  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    if captureSession.isRunning {
        captureSession.stopRunning()
    }
  }
}

extension ScanViewController: AVCaptureMetadataOutputObjectsDelegate {
  func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
    if metadataObjects.isEmpty {
      return
    }
    
    let metadataObj = metadataObjects[0] as! AVMetadataMachineReadableCodeObject
    
    if metadataObj.type == AVMetadataObject.ObjectType.qr {
      if let code = metadataObj.stringValue {
        delegate?.scanViewController(self, didScan: code)
        captureSession.stopRunning()
        DispatchQueue.main.async {
            self.dismiss(animated: true, completion: nil)
        }
      }
    }
  }
}
