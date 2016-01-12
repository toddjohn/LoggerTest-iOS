//
//  LogMessage.swift
//  LoggerTest
//
//  Created by Todd Johnson on 1/7/16.
//  Copyright © 2016 Todd Johnson. All rights reserved.
//

import Foundation

enum LogLevel: Int {
    case None = 0
    case Error
    case Warning
    case Info
    case Debug
    case Verbose
}

class LogMessage {

    private static let logger = LogMessage()
    private let loggerDateFormatter = NSDateFormatter()
    private let julianDateFormatter = NSDateFormatter()
    private let messageQueue: dispatch_queue_t
    private var loggingLevel = LogLevel.Info
    private var logfileHandle: NSFileHandle?

    private init() {
        self.loggerDateFormatter.dateFormat = "y-MM-d HH:mm:ss.SSS"
        self.julianDateFormatter.dateFormat = "g"
        self.messageQueue = dispatch_queue_create("com.toddjohn.LogMessage", DISPATCH_QUEUE_SERIAL)
    }

    deinit {
        self.logfileHandle?.synchronizeFile()
        self.logfileHandle?.closeFile()
    }

    private func closeLogFile() {
        self.logfileHandle?.synchronizeFile()
        self.logfileHandle?.closeFile()
        self.logfileHandle = nil
    }

    private func getJulianDay(date: NSDate? = nil) -> Int {
        var formateDate: NSDate! = date
        if formateDate == nil {
            formateDate = NSDate()
        }

        let stringDay = self.julianDateFormatter.stringFromDate(formateDate)
        return Int(stringDay)!
    }

    private func getLogfileName() -> String {
        return NSHomeDirectory() + "/Documents/CurrentLog.txt"
    }

    private func getBackupFileName() -> String {
        return NSHomeDirectory() + "/Documents/PreviousLog.txt"
    }

    private func backupLogFile() {
        let fileManager = NSFileManager.defaultManager()
        // delete old backup
        let backup = self.getBackupFileName()
        do {
            try fileManager.removeItemAtPath(backup)
        } catch {
            NSLog("Error removing backup file: \(error)")
        }
        // rename current file to backup
        let current = self.getLogfileName()
        do {
            try fileManager.moveItemAtPath(current, toPath: backup)
        } catch {
            NSLog("Error moving log file to backup: \(error)")
        }
    }

    private func getFileHandle() -> NSFileHandle {
        if self.logfileHandle != nil {
            return self.logfileHandle!
        }

        let logfileName = getLogfileName()
        let fileManager = NSFileManager.defaultManager()

        if fileManager.fileExistsAtPath(logfileName) {
            // check creation date to see if file needs to be migrated
            let today = self.getJulianDay()
            let fileDate = try! fileManager.attributesOfItemAtPath(logfileName)[NSFileCreationDate] as! NSDate
            let fileDay = self.getJulianDay(fileDate)
            if fileDay < today {
                self.backupLogFile()
                fileManager.createFileAtPath(logfileName, contents: nil, attributes: nil)
            }
        } else {
            fileManager.createFileAtPath(logfileName, contents: nil, attributes: nil)
        }
        self.logfileHandle = NSFileHandle(forWritingAtPath: logfileName)
        self.logfileHandle?.seekToEndOfFile()

        return self.logfileHandle!
    }

    private func logMessage(message: String, time: NSDate) {
        let timestamp = self.loggerDateFormatter.stringFromDate(time)
        let formattedString = "\(timestamp): \(message)"
        print(formattedString)

        let fileHandle = self.getFileHandle()
        let fileString = formattedString + "\n"
        let fileData = fileString.dataUsingEncoding(NSUTF8StringEncoding)
        fileHandle.writeData(fileData!)
    }

    private static func getFileBase(path: String) -> String {
        let pathParts = path.componentsSeparatedByString("/")
        let fileParts = pathParts.last!.componentsSeparatedByString(".")
        return fileParts[0]
    }

    private func enqueueLogMessage(prefix: String, message: String, file: String, function: String, line: UInt) {
        let now = NSDate()
        let fileBase = LogMessage.getFileBase(file)
        let formattedString = "\(prefix)[\(fileBase).\(function):\(line)] \(message)"
        dispatch_async(self.messageQueue, {
            self.logMessage(formattedString, time: now)
        })
    }

    // MARK: public methods

    static func setLogLevel(level: LogLevel) {
        LogMessage.logger.loggingLevel = level
    }

    static func flushLog() {
        dispatch_async(LogMessage.logger.messageQueue, {
            LogMessage.logger.closeLogFile()
        })
    }

    static func e(message: String, file: String = __FILE__, function: String = __FUNCTION__, line: UInt = __LINE__) {
        if LogMessage.logger.loggingLevel.rawValue < LogLevel.Error.rawValue { return }
        LogMessage.logger.enqueueLogMessage("E", message: message, file: file, function: function, line: line)
    }

    static func w(message: String, file: String = __FILE__, function: String = __FUNCTION__, line: UInt = __LINE__) {
        if LogMessage.logger.loggingLevel.rawValue < LogLevel.Warning.rawValue { return }
        LogMessage.logger.enqueueLogMessage("W", message: message, file: file, function: function, line: line)
    }

    static func i(message: String, file: String = __FILE__, function: String = __FUNCTION__, line: UInt = __LINE__) {
        if LogMessage.logger.loggingLevel.rawValue < LogLevel.Info.rawValue { return }
        LogMessage.logger.enqueueLogMessage("I", message: message, file: file, function: function, line: line)
    }

    static func d(message: String, file: String = __FILE__, function: String = __FUNCTION__, line: UInt = __LINE__) {
        if LogMessage.logger.loggingLevel.rawValue < LogLevel.Debug.rawValue { return }
        LogMessage.logger.enqueueLogMessage("D", message: message, file: file, function: function, line: line)
    }

    static func v(message: String, file: String = __FILE__, function: String = __FUNCTION__, line: UInt = __LINE__) {
        if LogMessage.logger.loggingLevel.rawValue < LogLevel.Verbose.rawValue { return }
        LogMessage.logger.enqueueLogMessage("V", message: message, file: file, function: function, line: line)
    }
}
