import os.log
import Servicing

let feedLogger = Logger(subsystem: "ai.dibba.ios", category: "FeedView")

let pageSize = 100
let initialFetchDelaySeconds: UInt64 = 3
let initialSyncCompletedKey = InitialSyncDefaults.completedKey
let initialSyncNextTokenKey = InitialSyncDefaults.nextTokenKey
