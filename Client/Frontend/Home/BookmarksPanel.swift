/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import UIKit
import Storage
import Shared
import XCGLogger

private let log = Logger.browserLogger

let BookmarkStatusChangedNotification = "BookmarkStatusChangedNotification"

struct BookmarksPanelUX {
    private static let BookmarkFolderHeaderViewChevronInset: CGFloat = 10
    private static let BookmarkFolderChevronSize: CGFloat = 20
    private static let BookmarkFolderChevronLineWidth: CGFloat = 4.0
    private static let BookmarkFolderTextColor = UIColor(red: 92/255, green: 92/255, blue: 92/255, alpha: 1.0)
    private static let BookmarkFolderTextFont = UIFont.systemFontOfSize(UIConstants.DefaultMediumFontSize, weight: UIFontWeightMedium)
}

class BookmarksPanel: SiteTableViewController, HomePanel {
    weak var homePanelDelegate: HomePanelDelegate? = nil
    var source: BookmarksModel?
    var parentFolders = [GUID]()
    var bookmarkFolder = BookmarkRoots.MobileFolderGUID

    private let BookmarkFolderCellIdentifier = "BookmarkFolderIdentifier"
    private let BookmarkFolderHeaderViewIdentifier = "BookmarkFolderHeaderIdentifier"

    private lazy var defaultIcon: UIImage = {
        return UIImage(named: "defaultFavicon")!
    }()
    
    init() {
        super.init(nibName: nil, bundle: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "notificationReceived:", name: NotificationFirefoxAccountChanged, object: nil)

        self.tableView.registerClass(BookmarkFolderTableViewCell.self, forCellReuseIdentifier: BookmarkFolderCellIdentifier)
        self.tableView.registerClass(BookmarkFolderTableViewHeader.self, forHeaderFooterViewReuseIdentifier: BookmarkFolderHeaderViewIdentifier)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self, name: NotificationFirefoxAccountChanged, object: nil)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // if we've not already set a source for this panel fetch a new model
        // otherwise just use the existing source to select a folder
        guard let source = self.source else {
            // Get all the bookmarks split by folders
            profile.bookmarks.modelForFolder(bookmarkFolder).upon(onModelFetched)
            return
        }
        source.selectFolder(bookmarkFolder).upon(onModelFetched)
    }

    func notificationReceived(notification: NSNotification) {
        switch notification.name {
        case NotificationFirefoxAccountChanged:
            self.reloadData()
            break
        default:
            // no need to do anything at all
            log.warning("Received unexpected notification \(notification.name)")
            break
        }
    }

    private func onModelFetched(result: Maybe<BookmarksModel>) {
        guard let model = result.successValue else {
            self.onModelFailure(result.failureValue)
            return
        }
        self.onNewModel(model)
    }

    private func onNewModel(model: BookmarksModel) {
        self.source = model
        self.title = parentFolders.isEmpty ? NSLocalizedString("Bookmarks", comment: "Panel accessibility label") : model.current.title
        dispatch_async(dispatch_get_main_queue()) {
            self.tableView.reloadData()
        }
    }

    private func onModelFailure(e: Any) {
        log.error("Error: failed to get data: \(e)")
    }

    // for each folder in the hierarchy, fetch the model and then push the next view controller
    // on the stack and continue recursively till we've traversed the hierarchy
    // we have to do this otherwise each BookmarksPanel does not have access to the right model in order
    // to load the appropriate folder and create the backwards navigation
    func restoreFolderHierarchy(hierarchy: [GUID], fromIndex: Int) {
        if fromIndex < hierarchy.count {
            profile.bookmarks.modelForFolder(bookmarkFolder).uponQueue(dispatch_get_main_queue()) { result in
                self.onModelFetched(result)
                let folder = hierarchy[fromIndex]

                let nextPanel = self.newBookmarkPanel(forFolder: folder)
                self.navigationController?.pushViewController(nextPanel, animated: false)

                nextPanel.restoreFolderHierarchy(hierarchy, fromIndex: fromIndex + 1)
            }
        }
    }

    private func newBookmarkPanel(forFolder guid: GUID) -> BookmarksPanel {
        let nextController = BookmarksPanel()
        nextController.profile = self.profile
        if let source = source {
            nextController.parentFolders = parentFolders + [source.current.guid]
            nextController.source = source
        }
        nextController.bookmarkFolder = guid
        nextController.homePanelDelegate = self.homePanelDelegate

        return nextController
    }

    private func updateBookmarkFolderState(withFolder guid: GUID) {
        let bookmarkHierarchy: [GUID] = parentFolders + [guid]
        self.homePanelDelegate?.homePanel?(self, didSelectBookmarkFolder: bookmarkHierarchy.joinWithSeparator(","))
    }

    override func reloadData() {
        self.source?.reloadData().upon(onModelFetched)
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return source?.current.count ?? 0
    }

    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        guard let source = source, bookmark = source.current[indexPath.row] else { return super.tableView(tableView, cellForRowAtIndexPath: indexPath) }
        let cell: UITableViewCell
        if let _ = bookmark as? BookmarkFolder {
            cell = tableView.dequeueReusableCellWithIdentifier(BookmarkFolderCellIdentifier, forIndexPath: indexPath)
        } else {
            cell = super.tableView(tableView, cellForRowAtIndexPath: indexPath)
            if let url = bookmark.favicon?.url.asURL where url.scheme == "asset" {
                cell.imageView?.image = UIImage(named: url.host!)
            } else {
                cell.imageView?.setIcon(bookmark.favicon, withPlaceholder: self.defaultIcon)
            }
        }

        switch (bookmark) {
            case let item as BookmarkItem:
                if item.title.isEmpty {
                    cell.textLabel?.text = item.url
                } else {
                    cell.textLabel?.text = item.title
                }
            default:
                // Bookmark folders don't have a good fallback if there's no title. :(
                cell.textLabel?.text = bookmark.title
        }

        return cell
    }

    func tableView(tableView: UITableView, willDisplayCell cell: UITableViewCell, forRowAtIndexPath indexPath: NSIndexPath) {
        if let cell = cell as? BookmarkFolderTableViewCell {
            cell.textLabel?.font = BookmarksPanelUX.BookmarkFolderTextFont
        }
    }

    override func tableView(tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        // Don't show a header for the root
        if source == nil || parentFolders.isEmpty {
            return nil
        }
        guard let header = tableView.dequeueReusableHeaderFooterViewWithIdentifier(BookmarkFolderHeaderViewIdentifier) as? BookmarkFolderTableViewHeader else { return nil }

        // register as delegate to ensure we get notified when the user interacts with this header
        if header.delegate == nil {
            header.delegate = self
        }

        if let navController = self.navigationController {
            let vcIndex: Int
            if navController.viewControllers.count > 1 {
                vcIndex = navController.viewControllers.count - 2
            } else {
                vcIndex = 0
            }
            let parentTitle = navController.viewControllers[vcIndex].title
            header.textLabel?.text = parentTitle
        }

        return header
    }

    override func tableView(tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        // Don't show a header for the root. If there's no root (i.e. source == nil), we'll also show no header.
        if source == nil || parentFolders.isEmpty {
            return 0
        }

        return SiteTableViewControllerUX.RowHeight
    }

    func tableView(tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        if let header = view as? BookmarkFolderTableViewHeader {
            // for some reason specifying the font in header view init is being ignored, so setting it here
            header.textLabel?.font = BookmarksPanelUX.BookmarkFolderTextFont
        }
    }

    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        tableView.deselectRowAtIndexPath(indexPath, animated: false)
        if let source = source {
            let bookmark = source.current[indexPath.row]
            updateBookmarkFolderState(withFolder: source.current.guid)
            switch (bookmark) {
            case let item as BookmarkItem:
                homePanelDelegate?.homePanel(self, didSelectURL: NSURL(string: item.url)!, visitType: VisitType.Bookmark)
                break

            case let folder as BookmarkFolder:
                self.navigationController?.pushViewController(newBookmarkPanel(forFolder: folder.guid), animated: true)
                break

            default:
                // Weird.
                break        // Just here until there's another executable statement (compiler requires one).
            }
        }
    }

    func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        // Intentionally blank. Required to use UITableViewRowActions
    }

    func tableView(tableView: UITableView, editingStyleForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCellEditingStyle {
        if source == nil {
            return .None
        }

        if source!.current.itemIsEditableAtIndex(indexPath.row) ?? false {
            return .Delete
        }

        return .None
    }

    func tableView(tableView: UITableView, editActionsForRowAtIndexPath indexPath: NSIndexPath) -> [AnyObject]? {
        if source == nil {
            return [AnyObject]()
        }

        let title = NSLocalizedString("Delete", tableName: "BookmarkPanel", comment: "Action button for deleting bookmarks in the bookmarks panel.")

        let delete = UITableViewRowAction(style: UITableViewRowActionStyle.Default, title: title, handler: { (action, indexPath) in
            if let bookmark = self.source?.current[indexPath.row] {
                // Why the dispatches? Because we call success and failure on the DB
                // queue, and so calling anything else that calls through to the DB will
                // deadlock. This problem will go away when the bookmarks API switches to
                // Deferred instead of using callbacks.
                // TODO: it's now time for this.
                self.profile.bookmarks.remove(bookmark).uponQueue(dispatch_get_main_queue()) { res in
                    if let err = res.failureValue {
                        self.onModelFailure(err)
                        return
                    }

                    dispatch_async(dispatch_get_main_queue()) {
                        self.source?.reloadData().upon {
                            guard let model = $0.successValue else {
                                self.onModelFailure($0.failureValue)
                                return
                            }
                            dispatch_async(dispatch_get_main_queue()) {
                                tableView.beginUpdates()
                                self.tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: UITableViewRowAnimation.Left)
                                self.source = model

                                tableView.endUpdates()

                                NSNotificationCenter.defaultCenter().postNotificationName(BookmarkStatusChangedNotification, object: bookmark, userInfo:["added":false])
                            }
                        }
                    }
                }
            }
        })

        return [delete]
    }
}

private protocol BookmarkFolderTableViewHeaderDelegate {
    func didSelectHeader()
}

extension BookmarksPanel: BookmarkFolderTableViewHeaderDelegate {
    private func didSelectHeader() {
        self.navigationController?.popViewControllerAnimated(true)
    }
}

class BookmarkFolderTableViewCell: TwoLineTableViewCell {
    private let ImageMargin: CGFloat = 12

    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.backgroundColor = SiteTableViewControllerUX.HeaderBackgroundColor
        textLabel?.backgroundColor = UIColor.clearColor()
        textLabel?.tintColor = BookmarksPanelUX.BookmarkFolderTextColor
        textLabel?.font = BookmarksPanelUX.BookmarkFolderTextFont

        imageView?.image = UIImage(named: "bookmarkFolder")

        let chevron = ChevronView(direction: .Right)
        chevron.tintColor = BookmarksPanelUX.BookmarkFolderTextColor
        chevron.frame = CGRectMake(0, 0, BookmarksPanelUX.BookmarkFolderChevronSize, BookmarksPanelUX.BookmarkFolderChevronSize)
        chevron.lineWidth = BookmarksPanelUX.BookmarkFolderChevronLineWidth
        accessoryView = chevron

        separatorInset = UIEdgeInsetsZero
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        // doing this here as TwoLineTableViewCell changes the imageView frame in it's layoutSubviews and we have to make sure it is right
        if let imageSize = imageView?.image?.size {
            imageView?.frame = CGRectMake(ImageMargin, (frame.height - imageSize.width) / 2, imageSize.width, imageSize.height)
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private class BookmarkFolderTableViewHeader : SiteTableViewHeader {
    var delegate: BookmarkFolderTableViewHeaderDelegate?

    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        // set the background color to white
        self.backgroundView = UIView(frame: self.bounds)
        self.backgroundView?.backgroundColor = UIColor.whiteColor()
        contentView.backgroundColor = UIColor.clearColor()

        textLabel?.textColor = UIConstants.HighlightBlue
        let chevron = ChevronView(direction: .Left)
        chevron.tintColor = UIConstants.HighlightBlue
        chevron.frame = CGRectMake(BookmarksPanelUX.BookmarkFolderHeaderViewChevronInset, (SiteTableViewControllerUX.RowHeight / 2) - BookmarksPanelUX.BookmarkFolderHeaderViewChevronInset, BookmarksPanelUX.BookmarkFolderChevronSize, BookmarksPanelUX.BookmarkFolderChevronSize)
        chevron.lineWidth = BookmarksPanelUX.BookmarkFolderChevronLineWidth
        addSubview(chevron)

        userInteractionEnabled = true

        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: "viewWasTapped:")
        tapGestureRecognizer.numberOfTapsRequired = 1
        addGestureRecognizer(tapGestureRecognizer)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private override func layoutSubviews() {
        super.layoutSubviews()

        // doing this here as SiteTableViewHeader changes the textLabel frame in it's layoutSubviews and we have to make sure it is right
        if var textLabelFrame = textLabel?.frame {
            textLabelFrame.origin.x += (BookmarksPanelUX.BookmarkFolderChevronSize + (BookmarksPanelUX.BookmarkFolderHeaderViewChevronInset / 2))
            textLabel?.frame = textLabelFrame
        }
    }

    @objc private func viewWasTapped(gestureRecognizer: UITapGestureRecognizer) {
        delegate?.didSelectHeader()
    }
}
