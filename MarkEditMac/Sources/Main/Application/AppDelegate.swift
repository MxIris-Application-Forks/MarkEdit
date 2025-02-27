//
//  AppDelegate.swift
//  MarkEditMac
//
//  Created by cyan on 12/12/22.

import AppKit
import AppKitExtensions
import SettingsUI

@NSApplicationMain
final class AppDelegate: NSObject, NSApplicationDelegate {
  @IBOutlet weak var mainFileMenu: NSMenu?
  @IBOutlet weak var mainEditMenu: NSMenu?
  @IBOutlet weak var mainWindowMenu: NSMenu?

  @IBOutlet weak var copyPandocCommandMenu: NSMenu?
  @IBOutlet weak var openFileInMenu: NSMenu?
  @IBOutlet weak var reopenFileMenu: NSMenu?
  @IBOutlet weak var lineEndingsMenu: NSMenu?
  @IBOutlet weak var editCommandsMenu: NSMenu?
  @IBOutlet weak var editFindMenu: NSMenu?
  @IBOutlet weak var textFormatMenu: NSMenu?
  @IBOutlet weak var formatHeadersMenu: NSMenu?

  @IBOutlet weak var lineEndingsLFItem: NSMenuItem?
  @IBOutlet weak var lineEndingsCRLFItem: NSMenuItem?
  @IBOutlet weak var lineEndingsCRItem: NSMenuItem?
  @IBOutlet weak var editUndoItem: NSMenuItem?
  @IBOutlet weak var editRedoItem: NSMenuItem?
  @IBOutlet weak var editReadOnlyItem: NSMenuItem?
  @IBOutlet weak var formatBulletItem: NSMenuItem?
  @IBOutlet weak var formatNumberingItem: NSMenuItem?
  @IBOutlet weak var formatTodoItem: NSMenuItem?
  @IBOutlet weak var formatCodeItem: NSMenuItem?
  @IBOutlet weak var formatCodeBlockItem: NSMenuItem?
  @IBOutlet weak var formatMathItem: NSMenuItem?
  @IBOutlet weak var formatMathBlockItem: NSMenuItem?
  @IBOutlet weak var windowFloatingItem: NSMenuItem?

  private var appearanceObservation: NSKeyValueObservation?
  private var settingsWindowController: NSWindowController?

  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.appearance = AppPreferences.General.appearance.resolved()
    appearanceObservation = NSApp.observe(\.effectiveAppearance) { _, _ in
      AppTheme.current.updateAppearance()
    }

    UserDefaults.overwriteTextCheckerOnce()
    EditorCustomization.createFiles()

    NSObject.swizzleAccessibilityBundlesOnce
    NSSpellChecker.swizzleInlineCompletionEnabledOnce
    NSSpellChecker.swizzleCorrectionIndicatorOnce

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(windowDidResignKey(_:)),
      name: NSWindow.didResignKeyNotification,
      object: nil
    )

    DispatchQueue.afterDelay(seconds: 0.2) {
      EditorReusePool.shared.warmUp()
    }

    DispatchQueue.afterDelay(seconds: 2.0) {
      Task {
        await AppUpdater.checkForUpdates(explicitly: false)
      }
    }

    // Check for updates on a weekly basis, for users who never quit apps
    Timer.scheduledTimer(withTimeInterval: 7 * 24 * 60 * 60, repeats: true) { _ in
      Task {
        await AppUpdater.checkForUpdates(explicitly: false)
      }
    }
  }
}

// MARK: - Private

private extension AppDelegate {
  @objc func windowDidResignKey(_ notification: Notification) {
    // To reduce the glitches between switching windows,
    // close openPanel once we don't have any key windows.
    //
    // Delay because there's no keyWindow during window transitions.
    DispatchQueue.afterDelay(seconds: 0.5) {
      if NSApp.windows.allSatisfy({ !$0.isKeyWindow }) {
        NSApp.closeOpenPanels()
      }
    }
  }

  @IBAction func checkForUpdates(_ sender: Any?) {
    Task {
      await AppUpdater.checkForUpdates(explicitly: true)
    }
  }

  @IBAction func showPreferences(_ sender: Any?) {
    if settingsWindowController == nil {
      settingsWindowController = SettingsRootViewController.withTabs([
        .editor,
        .assistant,
        .general,
        .window,
      ])

      // The window size relies on the SwiftUI content view size, it takes time
      DispatchQueue.main.async {
        self.settingsWindowController?.showWindow(self)
      }
    } else {
      settingsWindowController?.showWindow(self)
    }
  }

  @IBAction func showHelp(_ sender: Any?) {
    if let url = URL(string: "https://github.com/MarkEdit-app/MarkEdit/wiki") {
      NSWorkspace.shared.open(url)
    }
  }

  @IBAction func openIssueTracker(_ sender: Any?) {
    if let url = URL(string: "https://github.com/MarkEdit-app/MarkEdit/issues") {
      NSWorkspace.shared.open(url)
    }
  }

  @IBAction func openVersionHistory(_ sender: Any?) {
    if let url = URL(string: "https://github.com/MarkEdit-app/MarkEdit/releases") {
      NSWorkspace.shared.open(url)
    }
  }
}
