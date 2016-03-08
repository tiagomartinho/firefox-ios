/* This Source Code Form is subject to the terms of the Mozilla Public
* License, v. 2.0. If a copy of the MPL was not distributed with this
* file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import UIKit
import NotificationCenter
import Shared
import SnapKit

private let log = Logger.browserLogger

private let privateBrowsingColor = UIColor(colorString: "CE6EFC")

@objc (TodayViewController)
class TodayViewController: UIViewController, NCWidgetProviding {

    override func viewDidLoad() {
        super.viewDidLoad()
        self.preferredContentSize = CGSizeMake(0, 200)

        let effectView = UIVisualEffectView(effect: UIVibrancyEffect.notificationCenterVibrancyEffect())
        effectView.frame = self.view.bounds
        effectView.autoresizingMask = self.view.autoresizingMask

        self.view = effectView
        self.view.tintColor = UIColor.clearColor()

        let buttonContainer = UIView()
        self.view.addSubview(buttonContainer)

        buttonContainer.snp_makeConstraints { make in
            make.center.equalTo(view.snp_center)
            make.size.equalTo(view.snp_size)
        }

        let newTabButton = createNewTabButton()
        buttonContainer.addSubview(newTabButton)
        newTabButton.snp_makeConstraints { make in
            make.topMargin.equalTo(10)
            make.leftMargin.equalTo(10)
            make.height.width.equalTo(44)
        }

        let newPrivateTabButton = createNewPrivateTabButton()
        buttonContainer.addSubview(newPrivateTabButton)

        newPrivateTabButton.snp_makeConstraints { make in
            make.centerY.equalTo(newTabButton.snp_centerY)
            make.size.equalTo(newTabButton.snp_size)
        }

        let newTabLabel = createNewTabLabel()
        buttonContainer.addSubview(newTabLabel)
        alignButton(newTabButton, withLabel: newTabLabel)

        let newPrivateTabLabel = createNewPrivateTabLabel()
        buttonContainer.addSubview(newPrivateTabLabel)

        newPrivateTabLabel.snp_makeConstraints { make in
            make.left.equalTo(newTabLabel.snp_right).offset(22)
        }

        alignButton(newPrivateTabButton, withLabel: newPrivateTabLabel)

    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
    }

    private func alignButton(button: UIButton, withLabel label: UILabel) {
        label.snp_makeConstraints { make in
            make.centerX.equalTo(button.snp_centerX)
            make.centerY.equalTo(button.snp_centerY).offset(44)
        }
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

    // MARK: Button and label creation

    private func createNewTabLabel() -> UILabel {
        return createButtonLabel(NSLocalizedString("New Tab", comment: "New Tab button label"))
    }

    private func createNewPrivateTabLabel() -> UILabel {
        return createButtonLabel(NSLocalizedString("New Private Tab", comment: "New Private Tab button label"), color: privateBrowsingColor)
    }

    private func createButtonLabel(text: String, color: UIColor = UIColor.whiteColor()) -> UILabel {
        let label = UILabel()
        label.text = text
        label.textColor = color
        return label
    }

    private func createNewTabButton() -> UIButton {
        let button = UIButton()
        button.addTarget(self, action: Selector("onPressNewTab:"), forControlEvents: .TouchUpInside)
        button.setImage(UIImage(named: "new_tab_button_normal"), forState: .Normal)
        button.setImage(UIImage(named: "new_tab_button_highlight"), forState: .Highlighted)
        return button
    }

    private func createNewPrivateTabButton() -> UIButton {
        let button = UIButton()
        button.addTarget(self, action: Selector("onPressNewPrivateTab:"), forControlEvents: .TouchUpInside)
        button.setImage(UIImage(named: "new_private_tab_button_normal"), forState: .Normal)
        button.setImage(UIImage(named: "new_private_tab_button_highlight"), forState: .Highlighted)
        return button
    }

    // MARK: Button behaviour

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
