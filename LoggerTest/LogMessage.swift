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
    private let messageQueue: dispatch_queue_t
    private var loggingLevel = LogLevel.Info
    private var logfileHandle: NSFileHandle?
    private var logfileDay: Int64? = nil
    private var backupDays: UInt = 2

    private init() {
        self.loggerDateFormatter.dateFormat = "y-MM-d HH:mm:ss.SSS"
        self.messageQueue = dispatch_queue_create("com.toddjohn.LogMessage", DISPATCH_QUEUE_SERIAL)
    }

    deinit {
        self.closeLogFile()
    }

    private func closeLogFile() {
        self.logfileHandle?.synchronizeFile()
        self.logfileHandle?.closeFile()
        self.logfileHandle = nil
        self.logfileDay = nil
    }

    private func getDay(date: NSDate) -> Int64 {
        let daySeconds: Int64 = 60 * 60 * 24

        let seconds = Int64(date.timeIntervalSinceReferenceDate)
        let timeZone = NSTimeZone.localTimeZone()
        let timeZoneSeconds = Int64(timeZone.secondsFromGMT)
        let localSeconds = seconds + timeZoneSeconds
        let day = localSeconds / daySeconds

        return day
    }

    private func getLogfileName() -> String {
        return NSHomeDirectory() + "/Documents/CurrentLog.txt"
    }

    private func getBackupFileName(daysAgo: UInt) -> String {
        return NSHomeDirectory() + "/Documents/PreviousLog\(daysAgo).txt"
    }

    private func backupLogFile(backupName: String, currentName: String) {
        let fileManager = NSFileManager.defaultManager()
        // delete old backup
        do {
            try fileManager.removeItemAtPath(backupName)
        } catch let error as NSError {
            // Ignore file not found errors
            if error.code != NSFileNoSuchFileError {
                NSLog("Error removing backup file: \(error)")
            }
        }
        // rename current file to backup
        do {
            try fileManager.moveItemAtPath(currentName, toPath: backupName)
        } catch {
            NSLog("Error moving log file to backup: \(error)")
        }
    }

    private func shiftBackupFiles() {
        if self.backupDays > 1 {
            let fileRange = 2...self.backupDays
            for i in fileRange.reverse() {
                let previous = self.getBackupFileName(i)
                let next = self.getBackupFileName(i - 1)
                self.backupLogFile(previous, currentName: next)
            }
        }
        let backup = self.getBackupFileName(1)
        let current = self.getLogfileName()
        self.backupLogFile(backup, currentName: current)
    }

    private func createLogfile(filename: String, today: Int64) {
        let fileManager = NSFileManager.defaultManager()
        if fileManager.fileExistsAtPath(filename) {
            let fileAttributes = try! fileManager.attributesOfItemAtPath(filename)
            let fileDate = fileAttributes[NSFileCreationDate] as! NSDate
            let fileDay = self.getDay(fileDate)
            // check creation date to see if file needs to be migrated
            if fileDay < today {
                self.shiftBackupFiles()
                fileManager.createFileAtPath(filename, contents: nil, attributes: nil)
            }
        } else {
            fileManager.createFileAtPath(filename, contents: nil, attributes: nil)
        }
    }

    private func getFileHandle(messageDate: NSDate) -> NSFileHandle {
        let logfileName = getLogfileName()
        let today = self.getDay(messageDate)
        if self.logfileDay < today {
            self.closeLogFile()
            self.createLogfile(logfileName, today: today)
            self.logfileDay = today
        } else {
            precondition(self.logfileHandle != nil, "Logfile day is initialized, but file handle is nil")
            return self.logfileHandle!
        }

        self.logfileHandle = NSFileHandle(forWritingAtPath: logfileName)
        self.logfileHandle?.seekToEndOfFile()

        return self.logfileHandle!
    }

    private func logMessage(message: String, time: NSDate) {
        let timestamp = self.loggerDateFormatter.stringFromDate(time)
        let formattedString = "\(timestamp): \(message)"
        print(formattedString)

        let fileHandle = self.getFileHandle(time)
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

    static func setBackupDays(days: UInt) {
        let maxBackupDays: UInt = 5
        LogMessage.logger.backupDays = min(days, maxBackupDays)
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
