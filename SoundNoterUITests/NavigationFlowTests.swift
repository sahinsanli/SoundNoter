import XCTest

/// Uçtan uca akış testi: Splash → Onboarding → (buton) → Login ekranı.
/// Onboarding butonunun çalıştığını kanıtlar.
final class NavigationFlowTests: XCTestCase {

    override func setUp() {
        continueAfterFailure = false
    }

    func testSplashOnboardingLoginFlow() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTestResetDefaults"]
        app.launch()

        // 1) Splash 1.6s sürer — onboarding başlığını bekle (max 10sn).
        let kaydetTitle = app.staticTexts["Kaydet"]
        let onboardingAppeared = kaydetTitle.waitForExistence(timeout: 10)
        if !onboardingAppeared {
            // Teşhis: ekran görüntüsü + tüm erişilebilir metinler.
            let attachment = XCTAttachment(screenshot: app.screenshot())
            attachment.name = "onboarding-not-found"
            attachment.lifetime = .keepAlways
            add(attachment)
            print("🧪 DEBUG — visible staticTexts: \(app.staticTexts.allElementsBoundByIndex.prefix(12).map(\.label))")
            print("🧪 DEBUG — visible buttons: \(app.buttons.allElementsBoundByIndex.prefix(12).map(\.label))")
        }
        XCTAssertTrue(onboardingAppeared, "Onboarding 1. sayfa açılmadı")

        // 2) "Atla" butonuna bas → onboarding'i geçmeli.
        let skipButton = app.buttons["Atla"]
        XCTAssertTrue(skipButton.waitForExistence(timeout: 3), "Atla butonu bulunamadı")
        skipButton.tap()

        // 3) Login ekranına geçildi mi? — buton etiketi HStack nedeniyle
        // "Google ile devam et" olmayabilir; "Google" içeren herhangi bir buton.
        let anyGoogleButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Google'")).firstMatch
        XCTAssertTrue(anyGoogleButton.waitForExistence(timeout: 5), "❌ Onboarding geçilemedi — Login ekranı açılmadı")

        // 4) Kalıcılık: uygulamayı yeniden başlat — onboarding atlanmalı.
        app.terminate()
        app.launch()
        let anyGoogleButton2 = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Google'")).firstMatch
        XCTAssertTrue(anyGoogleButton2.waitForExistence(timeout: 8), "❌ Onboarding kalıcı değil — açılışta tekrar soruldu")
    }
}
