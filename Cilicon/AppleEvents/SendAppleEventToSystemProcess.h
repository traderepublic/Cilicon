#ifndef __Utilities__SendAppleEventToSystemProcess__
#define __Utilities__SendAppleEventToSystemProcess__

#include <stdio.h>
#include <CoreServices/CoreServices.h>
#include <Carbon/Carbon.h>

extern OSStatus SendAppleEventToSystemProcess(AEEventID EventToSend);

#endif
