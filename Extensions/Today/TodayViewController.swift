/* This Source Code Form is subject to the terms of the Mozilla Public
* License, v. 2.0. If a copy of the MPL was not distributed with this
* file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import UIKit
import NotificationCenter
import Shared
import SnapKit

private let log = Logger.browserLogger

@objc (TodayViewController)
class TodayViewController: UIViewController, NCWidgetProviding {


    private var buttons: [UIButton]?

    override func viewDidLoad() {
        super.viewDidLoad()
        self.preferredContentSize = CGSizeMake(0, 200)

        let effectView = UIVisualEffectView(effect: UIVibrancyEffect.notificationCenterVibrancyEffect())
        effectView.frame = self.view.bounds
        effectView.autoresizingMask = self.view.autoresizingMask

        let ogView = self.view
        self.view = effectView
        self.view.addSubview(ogView)
        self.view.tintColor = UIColor.clearColor()

//        view.backgroundColor = UIColor.blueColor()

        let buttonContainer = UIView()
        ogView.addSubview(buttonContainer)
//        buttonContainer.backgroundColor = UIColor.clearColor()

        buttonContainer.snp_remakeConstraints { make in
            make.center.equalTo(view.snp_center)
            make.size.equalTo(view.snp_size)
        }


        let newTabButton = createNewTabButton()
        buttonContainer.addSubview(newTabButton)
        newTabButton.snp_remakeConstraints { make in
            make.topMargin.equalTo(10)
            make.leftMargin.equalTo(10)
            make.height.width.equalTo(44)
        }

        let newPrivateTabButton = createNewPrivateTabButton()
        buttonContainer.addSubview(newPrivateTabButton)
        newPrivateTabButton.snp_remakeConstraints { make in
            make.centerY.equalTo(newTabButton.snp_centerY)
            make.centerX.equalTo(newTabButton.snp_centerX).offset(88)
            make.height.width.equalTo(newTabButton.snp_width)
        }

        buttons = [newTabButton, newPrivateTabButton]

    }

    private func createNewPrivateTabButton() -> UIButton {
        let button = UIButton()
        button.addTarget(self, action: Selector("onPressNewPrivateTab:"), forControlEvents: .TouchUpInside)
        button.setTitle("*", forState: .Normal)
        button.setTitle("-", forState: .Highlighted)
        return button
    }


    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        buttons?.forEach { b in
            roundButton(b)
        }
    }

    private func roundButton(button: UIButton) {
        button.layer.cornerRadius = 0.5 * button.bounds.size.width
        button.clipsToBounds = true
        button.layer.borderColor = UIColor.whiteColor().CGColor
        button.layer.borderWidth = 1
    }

    override func loadView() {
        view = UIView(frame:CGRect(x:0.0, y:0, width:320.0, height:200.0))
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func widgetPerformUpdateWithCompletionHandler(completionHandler: ((NCUpdateResult) -> Void)) {
        // Perform any setup necessary in order to update the view.

        // If an error is encountered, use NCUpdateResult.Failed
        // If there's no update required, use NCUpdateResult.NoData
        // If there's an update, use NCUpdateResult.NewData

        completionHandler(NCUpdateResult.NewData)
    }

    private func createNewTabButton() -> UIButton {
        let button = UIButton()
        button.addTarget(self, action: Selector("onPressNewTab:"), forControlEvents: .TouchUpInside)
        button.setTitle("+", forState: .Normal)
        button.setTitle("-", forState: .Highlighted)
        return button
    }

    @objc func onPressNewTab(view: UIView) {
        openContainingApp("firefox://")
    }

    @objc func onPressNewPrivateTab(view: UIView) {
        openContainingApp("firefox://?private=true")
    }

    private func openContainingApp(urlString: String) {
        self.extensionContext?.openURL(NSURL(string: urlString)!) { success in
            log.info("Extension opened containing app: \(success)")
        }
    }
}
