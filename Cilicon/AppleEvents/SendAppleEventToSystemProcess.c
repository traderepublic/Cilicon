#include "SendAppleEventToSystemProcess.h"

// From https://developer.apple.com/library/mac/qa/qa1134/_index.html
OSStatus SendAppleEventToSystemProcess(AEEventID EventToSend) {
	AEAddressDesc targetDesc;
	static const ProcessSerialNumber kPSNOfSystemProcess = { 0, kSystemProcess };
	AppleEvent eventReply = {typeNull, NULL};
	AppleEvent appleEventToSend = {typeNull, NULL};

	OSStatus error = AECreateDesc(typeProcessSerialNumber, &kPSNOfSystemProcess, sizeof(kPSNOfSystemProcess), &targetDesc);
	if (error != noErr) {
		return error;
	}

	error = AECreateAppleEvent(kCoreEventClass, EventToSend, &targetDesc, kAutoGenerateReturnID, kAnyTransactionID, &appleEventToSend);
	AEDisposeDesc(&targetDesc);

	if (error != noErr) {
		return error;
	}

	error = AESend(&appleEventToSend, &eventReply, kAENoReply, kAENormalPriority, kAEDefaultTimeout, NULL, NULL);
	AEDisposeDesc(&appleEventToSend);

	if (error != noErr) {
		return error;
	}

	AEDisposeDesc(&eventReply);

	return error;
}
