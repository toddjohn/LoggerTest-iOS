//
//  ViewController.swift
//  LoggerTest
//
//  Created by Todd Johnson on 1/7/16.
//  Copyright © 2016 Todd Johnson. All rights reserved.
//

import UIKit

class ViewController: UITableViewController {

    override func prefersStatusBarHidden() -> Bool {
        return true
    }

    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        guard let level = LogLevel(rawValue: indexPath.row+1) else { return }

        switch level {
        case .Error:
            LogMessage.e("Error message")
        case .Warning:
            LogMessage.w("Warning message")
        case .Info:
            LogMessage.i("Info message")
        case .Debug:
            LogMessage.d("Debug message")
        case .Verbose:
            LogMessage.v("Verbose message")
        default:
            break
        }
    }

    @IBAction func levelButton(sender: UIBarButtonItem) {
        let actionSheet = UIAlertController(title: "Log Level", message: "Select the level of allowed messages", preferredStyle: .ActionSheet)
        let errorAction = UIAlertAction(title: "Error", style: .Default, handler: { action in
            LogMessage.setLogLevel(LogLevel.Error)
        })
        let warningAction = UIAlertAction(title: "Warning", style: .Default, handler: { action in
            LogMessage.setLogLevel(LogLevel.Warning)
        })
        let infoAction = UIAlertAction(title: "Info", style: .Default, handler: { action in
            LogMessage.setLogLevel(LogLevel.Info)
        })
        let debugAction = UIAlertAction(title: "Debug", style: .Default, handler: { action in
            LogMessage.setLogLevel(LogLevel.Debug)
        })
        let verboseAction = UIAlertAction(title: "Verbose", style: .Default, handler: { action in
            LogMessage.setLogLevel(LogLevel.Verbose)
        })

        actionSheet.addAction(errorAction)
        actionSheet.addAction(warningAction)
        actionSheet.addAction(infoAction)
        actionSheet.addAction(debugAction)
        actionSheet.addAction(verboseAction)

        if let popoverController = actionSheet.popoverPresentationController {
            popoverController.barButtonItem = sender
        }

        self.presentViewController(actionSheet, animated: true, completion: nil)
    }
}

