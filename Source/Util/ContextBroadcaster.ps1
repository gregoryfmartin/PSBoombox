using namespace System

Set-StrictMode -Version Latest





###############################################################################
#
# CONTEXT BROADCASTER
#
# BROADCASTS EVENTS WITH CONTEXT PAYLOADS.
#
###############################################################################

Class ContextBroadcaster {
    ContextBroadcaster() {}

    Static [Void]StaticBroadcast(
        [String]$EventName,
        [Object]$Sender,
        [Context]$Context
    ) {
        $null = New-Event -SourceIdentifier $EventName -Sender $Sender -MessageData $Context
    }

    [Void]Broadcast(
        [String]$EventName,
        [Object]$Sender,
        [Context]$Context
    ) {
        $null = New-Event -SourceIdentifier $EventName -Sender $Sender -MessageData $Context
    }
}
