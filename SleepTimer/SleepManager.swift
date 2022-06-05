import IOKit.pwr_mgt

private var assertionID: IOPMAssertionID?

func disableScreenSleep(reason: String = "Disabling Screen Sleep") {
    guard assertionID == nil else {
        return
    }
    var assertionId: IOPMAssertionID = 0
    if IOPMAssertionCreateWithName(kIOPMAssertionTypeNoDisplaySleep as CFString,
                                   IOPMAssertionLevel(kIOPMAssertionLevelOn),
                                   reason as CFString,
                                   &assertionId) == kIOReturnSuccess {
        assertionID = assertionId
    }
}

func enableScreenSleep() {
    if let assertionId = assertionID {
        IOPMAssertionRelease(assertionId)
        assertionID = nil
    }
}
