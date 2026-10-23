{-# LANGUAGE NamedFieldPuns #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TypeApplications #-}
{-# OPTIONS_GHC -fno-warn-unrecognised-pragmas #-}

module Popopx.Messaging.Server.Prometheus
  ( ServerMetrics (..),
    RealTimeMetrics (..),
    RTSubscriberMetrics (..),
    rtsOptionsEnv,
    prometheusMetrics,
  ) where

import Data.Int (Int64)
import qualified Data.IntMap.Strict as IM
import Data.List (mapAccumL)
import Data.Text (Text)
import qualified Data.Text as T
import Data.Time.Clock (UTCTime (..), diffUTCTime)
import Data.Time.Clock.System (systemEpochDay)
import Data.Time.Format.ISO8601 (iso8601Show)
import Network.Socket (ServiceName)
import Popopx.Messaging.Server.MsgStore.Types (LoadedQueueCounts (..))
import Popopx.Messaging.Server.QueueStore.Types (EntityCounts (..))
import Popopx.Messaging.Server.Stats
import Popopx.Messaging.Transport (popopxMQVersion)
import Popopx.Messaging.Transport.Server (SocketStats (..))
import Popopx.Messaging.Util (tshow)

data ServerMetrics = ServerMetrics
  { statsData :: ServerStatsData,
    activeQueueCounts :: PeriodStatCounts,
    activeNtfCounts :: PeriodStatCounts,
    entityCounts :: EntityCounts,
    rtsOptions :: Text
  }

rtsOptionsEnv :: Text
rtsOptionsEnv = "SMP_RTS_OPTIONS"

data RealTimeMetrics = RealTimeMetrics
  { socketStats :: [(ServiceName, SocketStats)],
    threadsCount :: Int,
    clientsCount :: Int,
    deliveredSubs :: RTSubscriberMetrics,
    deliveredTimes :: TimeBuckets,
    smpSubs :: RTSubscriberMetrics,
    ntfSubs :: RTSubscriberMetrics,
    loadedCounts :: LoadedQueueCounts
  }

data RTSubscriberMetrics = RTSubscriberMetrics
  { subsCount :: Int,
    subClientsCount :: Int,
    subServicesCount :: Int,
    subServiceSubsCount :: Int64
  }

{-# FOURMOLU_DISABLE\n#-}
prometheusMetrics :: ServerMetrics -> RealTimeMetrics -> UTCTime -> Text
prometheusMetrics sm rtm ts =
  time <> queues <> subscriptions <> messages <> ntfMessages <> ntfs <> relays <> services <> names <> info
  where
    ServerMetrics {statsData, activeQueueCounts = ps, activeNtfCounts = psNtf, entityCounts, rtsOptions} = sm
    RealTimeMetrics
      { socketStats,
        threadsCount,
        clientsCount,
        deliveredSubs,
        deliveredTimes,
        smpSubs,
        ntfSubs,
        loadedCounts
      } = rtm
    ServerStatsData
      { _fromTime,
        _qCreated,
        _qSecured,
        _qDeletedAll,
        _qDeletedAllB,
        _qDeletedNew,
        _qDeletedSecured,
        _qBlocked,
        _qSub,
        _qSubAllB,
        _qSubAuth,
        _qSubDuplicate,
        _qSubProhibited,
        _qSubEnd,
        _qSubEndB,
        _ntfCreated,
        _ntfNewCreated,
        _ntfDeleted,
        _ntfDeletedB,
        _ntfSub,
        _ntfSubB,
        _ntfSubAuth,
        _ntfSubDuplicate,
        _msgSent,
        _msgSentAuth,
        _msgSentQuota,
        _msgSentLarge,
        _msgSentBlock,
        _msgRecv,
        _msgRecvAckTimes,
        _msgRecvGet,
        _msgGet,
        _msgGetNoMsg,
        _msgGetAuth,
        _msgGetDuplicate,
        _msgGetProhibited,
        _msgExpired,
        _msgSentNtf,
        _msgRecvNtf,
        _msgNtfs,
        _msgNtfsB,
        _msgNtfNoSub,
        _msgNtfLost,
        _msgNtfExpired,
        _pRelays,
        _pRelaysOwn,
        _pMsgFwds,
        _pMsgFwdsOwn,
        _pMsgFwdsRecv,
        _rcvServices,
        _ntfServices,
        _rcvServicesSubMsg,
        _rcvServicesSubDuplicate,
        _authDelayExceeded,
        _cmdSlotWaits,
        _cmdSlotWaitMs,
        _cmdSlotWaitMaxMs,
        _cmdSlotWaitTimeouts,
        _qCount,
        _msgCount,
        _ntfCount,
        _rslvStats
      } = statsData
    time =
      "# Recorded at: " <> T.pack (iso8601Show ts) <> "\n\
      \# Stats from: " <> T.pack (iso8601Show _fromTime) <> "\n\
      \\n"
    queues =
      "# Queues\n\
      \# ------\n\
      \\n\
      \# HELP popopx_smp_queues_created Created queues\n\
      \# TYPE popopx_smp_queues_created counter\n\
      \popopx_smp_queues_created " <> mshow _qCreated <> "\n# qCreated\n\
      \\n\
      \# HELP popopx_smp_queues_secured Secured queues\n\
      \# TYPE popopx_smp_queues_secured counter\n\
      \popopx_smp_queues_secured " <> mshow _qSecured <> "\n# qSecured\n\
      \\n\
      \# HELP popopx_smp_queues_deleted Deleted queues\n\
      \# TYPE popopx_smp_queues_deleted counter\n\
      \popopx_smp_queues_deleted{type=\"all\"} " <> mshow _qDeletedAll <> "\n# qDeleted\n\
      \popopx_smp_queues_deleted{type=\"new\"} " <> mshow _qDeletedNew <> "\n# qDeletedNew\n\
      \popopx_smp_queues_deleted{type=\"secured\"} " <> mshow _qDeletedSecured <> "\n# qDeletedSecured\n\
      \\n\
      \# HELP popopx_smp_queues_blocked Deleted queues\n\
      \# TYPE popopx_smp_queues_blocked counter\n\
      \popopx_smp_queues_blocked " <> mshow _qBlocked <> "\n# qBlocked\n\
      \\n\
      \# HELP popopx_smp_queues_deleted_batch Batched requests to delete queues\n\
      \# TYPE popopx_smp_queues_deleted_batch counter\n\
      \popopx_smp_queues_deleted_batch " <> mshow _qDeletedAllB <> "\n# qDeletedAllB\n\
      \\n\
      \# HELP popopx_smp_queues_total1 Total number of stored queues (first type of count).\n\
      \# TYPE popopx_smp_queues_total1 gauge\n\
      \popopx_smp_queues_total1 " <> mshow _qCount <> "\n# qCount\n\
      \\n\
      \# HELP popopx_smp_queues_total2 Total number of stored queues (second type of count).\n\
      \# TYPE popopx_smp_queues_total2 gauge\n\
      \popopx_smp_queues_total2 " <> mshow (queueCount entityCounts) <> "\n# qCount2\n\
      \\n\
      \# HELP popopx_smp_queues_daily Daily active queues.\n\
      \# TYPE popopx_smp_queues_daily gauge\n\
      \popopx_smp_queues_daily " <> mstr (dayCount ps) <> "\n# dayMsgQueues\n\
      \\n\
      \# HELP popopx_smp_queues_weekly Weekly active queues.\n\
      \# TYPE popopx_smp_queues_weekly gauge\n\
      \popopx_smp_queues_weekly " <> mstr (weekCount ps) <> "\n# weekMsgQueues\n\
      \\n\
      \# HELP popopx_smp_queues_monthly Monthly active queues.\n\
      \# TYPE popopx_smp_queues_monthly gauge\n\
      \popopx_smp_queues_monthly " <> mstr (monthCount ps) <> "\n# monthMsgQueues\n\
      \\n\
      \# HELP popopx_smp_queues_notify_daily Daily active queues with notifications.\n\
      \# TYPE popopx_smp_queues_notify_daily gauge\n\
      \popopx_smp_queues_notify_daily " <> mstr (dayCount psNtf) <> "\n# dayCountNtf\n\
      \\n\
      \# HELP popopx_smp_queues_notify_weekly Weekly active queues with notifications.\n\
      \# TYPE popopx_smp_queues_notify_weekly gauge\n\
      \popopx_smp_queues_notify_weekly " <> mstr (weekCount psNtf) <> "\n# weekCountNtf\n\
      \\n\
      \# HELP popopx_smp_queues_notify_monthly Monthly active queues with notifications.\n\
      \# TYPE popopx_smp_queues_notify_monthly gauge\n\
      \popopx_smp_queues_notify_monthly " <> mstr (monthCount psNtf) <> "\n# monthCountNtf\n\
      \\n\
      \# HELP popopx_smp_auth_delay_exceeded Responses with AUTH errors sent without delay, as processing took longer than the delay.\n\
      \# TYPE popopx_smp_auth_delay_exceeded counter\n\
      \popopx_smp_auth_delay_exceeded " <> mshow _authDelayExceeded <> "\n# authDelayExceeded\n\
      \\n\
      \# HELP popopx_smp_cmd_slot_wait_ms Time commands waited for a free slot of the connection concurrency limit, in ms.\n\
      \# TYPE popopx_smp_cmd_slot_wait_ms summary\n\
      \popopx_smp_cmd_slot_wait_ms_sum " <> mshow _cmdSlotWaitMs <> "\n# cmdSlotWaitMs\n\
      \popopx_smp_cmd_slot_wait_ms_count " <> mshow _cmdSlotWaits <> "\n# cmdSlotWaits\n\
      \\n\
      \# HELP popopx_smp_cmd_slot_wait_ms_max The longest wait for a free command slot, in ms.\n\
      \# TYPE popopx_smp_cmd_slot_wait_ms_max gauge\n\
      \popopx_smp_cmd_slot_wait_ms_max " <> mshow _cmdSlotWaitMaxMs <> "\n# cmdSlotWaitMaxMs\n\
      \\n\
      \# HELP popopx_smp_cmd_slot_wait_timeouts Commands not processed because the client timed out while they waited for a free slot.\n\
      \# TYPE popopx_smp_cmd_slot_wait_timeouts counter\n\
      \popopx_smp_cmd_slot_wait_timeouts " <> mshow _cmdSlotWaitTimeouts <> "\n# cmdSlotWaitTimeouts\n\
      \\n"
    subscriptions =
      "# Subscriptions\n\
      \# -------------\n\
      \\n\
      \# HELP popopx_smp_subscribtion_successes Successful subscriptions.\n\
      \# TYPE popopx_smp_subscribtion_successes counter\n\
      \popopx_smp_subscribtion_successes " <> mshow _qSub <> "\n# qSub\n\
      \\n\
      \# HELP popopx_smp_subscribtion_successes_batch Batched successful subscriptions.\n\
      \# TYPE popopx_smp_subscribtion_successes_batch counter\n\
      \popopx_smp_subscribtion_successes_batch " <> mshow _qSubAllB <> "\n# qSubAllB\n\
      \\n\
      \# HELP popopx_smp_subscribtion_end Ended subscriptions.\n\
      \# TYPE popopx_smp_subscribtion_end counter\n\
      \popopx_smp_subscribtion_end " <> mshow _qSubEnd <> "\n# qSubEnd\n\
      \\n\
      \# HELP popopx_smp_subscribtion_end_batch Batched ended subscriptions.\n\
      \# TYPE popopx_smp_subscribtion_end_batch counter\n\
      \popopx_smp_subscribtion_end_batch " <> mshow _qSubEndB <> "\n# qSubEndB\n\
      \\n\
      \# HELP popopx_smp_subscribtion_errors Subscription errors.\n\
      \# TYPE popopx_smp_subscribtion_errors counter\n\
      \popopx_smp_subscribtion_errors{type=\"auth\"} " <> mshow _qSubAuth <> "\n# qSubAuth\n\
      \popopx_smp_subscribtion_errors{type=\"duplicate\"} " <> mshow _qSubDuplicate <> "\n# qSubDuplicate\n\
      \popopx_smp_subscribtion_errors{type=\"prohibited\"} " <> mshow _qSubProhibited <> "\n# qSubProhibited\n\
      \\n"
    messages =
      "# Messages\n\
      \# --------\n\
      \\n\
      \# HELP popopx_smp_messages_sent Sent messages.\n\
      \# TYPE popopx_smp_messages_sent counter\n\
      \popopx_smp_messages_sent " <> mshow _msgSent <> "\n# msgSent\n\
      \\n\
      \# HELP popopx_smp_messages_sent_errors Total number of messages errors by type.\n\
      \# TYPE popopx_smp_messages_sent_errors counter\n\
      \popopx_smp_messages_sent_errors{type=\"auth\"} " <> mshow _msgSentAuth <> "\n# msgSentAuth\n\
      \popopx_smp_messages_sent_errors{type=\"quota\"} " <> mshow _msgSentQuota <> "\n# msgSentQuota\n\
      \popopx_smp_messages_sent_errors{type=\"large\"} " <> mshow _msgSentLarge <> "\n# msgSentLarge\n\
      \popopx_smp_messages_sent_errors{type=\"block\"} " <> mshow _msgSentBlock <> "\n# msgSentBlock\n\
      \\n\
      \# HELP popopx_smp_messages_received Received messages.\n\
      \# TYPE popopx_smp_messages_received counter\n\
      \popopx_smp_messages_received " <> mshow _msgRecv <> "\n# msgRecv\n\
      \\n\
      \# HELP popopx_smp_messages_expired Expired messages.\n\
      \# TYPE popopx_smp_messages_expired counter\n\
      \popopx_smp_messages_expired " <> mshow _msgExpired <> "\n# msgExpired\n\
      \\n\
      \# HELP popopx_smp_messages_total Total number of messages stored.\n\
      \# TYPE popopx_smp_messages_total gauge\n\
      \popopx_smp_messages_total " <> mshow _msgCount <> "\n# msgCount\n\
      \\n"
    ntfMessages =
      "# Notification messages (client)\n\
      \# ------------------------------\n\
      \\n\
      \# HELP popopx_smp_messages_notify_sent Sent messages with notification flag (cleint).\n\
      \# TYPE popopx_smp_messages_notify_sent counter\n\
      \popopx_smp_messages_notify_sent " <> mshow _msgSentNtf <> "\n# msgSentNtf\n\
      \\n\
      \# HELP popopx_smp_messages_notify_received Received messages with notification flag (client).\n\
      \# TYPE popopx_smp_messages_notify_received counter\n\
      \popopx_smp_messages_notify_received " <> mshow _msgRecvNtf <> "\n# msgRecvNtf\n\
      \\n\
      \# HELP popopx_smp_messages_notify_get_sent Requests to get messages with notification flag (client).\n\
      \# TYPE popopx_smp_messages_notify_get_sent counter\n\
      \popopx_smp_messages_notify_get_sent " <> mshow _msgGet <> "\n# msgGet\n\
      \\n\
      \# HELP popopx_smp_messages_notify_get_received Succesfully received get requests messages with notification flag (client).\n\
      \# TYPE popopx_smp_messages_notify_get_received counter\n\
      \popopx_smp_messages_notify_get_received " <> mshow _msgRecvGet <> "\n# msgRecvGet\n\
      \\n\
      \# HELP popopx_smp_messages_notify_get_errors Error events with messages with notification flag (client). \n\
      \# TYPE popopx_smp_messages_notify_get_errors counter\n\
      \popopx_smp_messages_notify_get_errors{type=\"nomsg\"} " <> mshow _msgGetNoMsg <> "\n# msgGetNoMsg\n\
      \popopx_smp_messages_notify_get_errors{type=\"auth\"} " <> mshow _msgGetAuth <> "\n# msgGetAuth\n\
      \popopx_smp_messages_notify_get_errors{type=\"duplicate\"} " <> mshow _msgGetDuplicate <> "\n# msgGetDuplicate\n\
      \popopx_smp_messages_notify_get_errors{type=\"prohibited\"} " <> mshow _msgGetProhibited <> "\n# msgGetProhibited\n\
      \\n\
      \# HELP popopx_smp_queues_notify_created Created queue notification credentials.\n\
      \# TYPE popopx_smp_queues_notify_created counter\n\
      \popopx_smp_queues_notify_created " <> mshow _ntfCreated <> "\n# ntfCreated\n\
      \\n\
      \# HELP popopx_smp_queues_notify_new_created Created new queues with notification credentials.\n\
      \# TYPE popopx_smp_queues_notify_new_created counter\n\
      \popopx_smp_queues_notify_new_created " <> mshow _ntfNewCreated <> "\n# ntfNewCreated\n\
      \\n\
      \# HELP popopx_smp_queues_notify_deleted Deleted queue notification credentials.\n\
      \# TYPE popopx_smp_queues_notify_deleted counter\n\
      \popopx_smp_queues_notify_deleted " <> mshow _ntfDeleted <> "\n# ntfDeleted\n\
      \\n\
      \# HELP popopx_smp_queues_notify_deleted_batch Deleted batched queue notification credentials.\n\
      \# TYPE popopx_smp_queues_notify_deleted_batch counter\n\
      \popopx_smp_queues_notify_deleted_batch " <> mshow _ntfDeletedB <> "\n# ntfDeletedB\n\
      \\n\
      \# HELP popopx_smp_queues_notify_total1 Total number of stored queues with notification flag (first type of count).\n\
      \# TYPE popopx_smp_queues_notify_total1 gauge\n\
      \popopx_smp_queues_notify_total1 " <> mshow _ntfCount <> "\n# ntfCount1\n\
      \\n\
      \# HELP popopx_smp_queues_notify_total2 Total number of stored queues with notification flag (second type of count).\n\
      \# TYPE popopx_smp_queues_notify_total2 gauge\n\
      \popopx_smp_queues_notify_total2 " <> mshow (notifierCount entityCounts) <> "\n# ntfCount2\n\
      \\n"
    ntfs =
      "# Notifications (server)\n\
      \# ----------------------\n\
      \\n\
      \# HELP popopx_smp_messages_ntf_successes Successful events with notification messages (to ntf server). \n\
      \# TYPE popopx_smp_messages_ntf_successes counter\n\
      \popopx_smp_messages_ntf_successes " <> mshow _msgNtfs <> "\n# msgNtfs\n\
      \\n\
      \# HELP popopx_smp_messages_ntf_successes_batch Successful batched events with notification messages (to ntf server). \n\
      \# TYPE popopx_smp_messages_ntf_successes_batch counter\n\
      \popopx_smp_messages_ntf_successes_batch " <> mshow _msgNtfsB <> "\n# msgNtfsB\n\
      \\n\
      \# HELP popopx_smp_messages_ntf_errors Error events with notification messages (to ntf server). \n\
      \# TYPE popopx_smp_messages_ntf_errors counter\n\
      \popopx_smp_messages_ntf_errors{type=\"nosub\"} " <> mshow _msgNtfNoSub <> "\n# msgNtfNoSub\n\
      \popopx_smp_messages_ntf_errors{type=\"lost\"} " <> mshow _msgNtfLost <> "\n# msgNtfLost\n\
      \popopx_smp_messages_ntf_errors{type=\"expired\"} " <> mshow _msgNtfExpired <> "\n# msgNtfExpired\n\
      \\n\
      \# HELP popopx_smp_subscription_ntf_requests Subscription requests with notification flag (from ntf server). \n\
      \# TYPE popopx_smp_subscription_ntf_requests counter\n\
      \popopx_smp_subscription_ntf_requests " <> mshow _ntfSub <> "\n# ntfSub\n\
      \\n\
      \# HELP popopx_smp_subscription_ntf_requests_batch Batched subscription requests with notification flag (from ntf server). \n\
      \# TYPE popopx_smp_subscription_ntf_requests_batch counter\n\
      \popopx_smp_subscription_ntf_requests_batch " <> mshow _ntfSubB <> "\n# ntfSubB\n\
      \\n\
      \# HELP popopx_smp_subscribtion_ntf_errors Subscription errors with notification flag (from ntf server). \n\
      \# TYPE popopx_smp_subscribtion_ntf_errors counter\n\
      \popopx_smp_subscribtion_ntf_errors{type=\"auth\"} " <> mshow _ntfSubAuth <> "\n# ntfSubAuth\n\
      \popopx_smp_subscribtion_ntf_errors{type=\"duplicate\"} " <> mshow _ntfSubDuplicate <> "\n# ntfSubDuplicate\n\
      \\n"
    relays =
      "# Relays\n\
      \# ------\n\
      \\n\
      \# HELP popopx_smp_relay_sessions_requests Session requests through relay.\n\
      \# TYPE popopx_smp_relay_sessions_requests counter\n\
      \popopx_smp_relay_sessions_requests{source=\"all\"} " <> mshow (_pRequests _pRelays) <> "\n# pRelays_pRequests\n\
      \popopx_smp_relay_sessions_requests{source=\"own\"} " <> mshow (_pRequests _pRelaysOwn) <> "\n# pRelaysOwn_pRequests\n\
      \\n\
      \# HELP popopx_smp_relay_sessions_successes Successful session events through relay.\n\
      \# TYPE popopx_smp_relay_sessions_successes counter\n\
      \popopx_smp_relay_sessions_successes{source=\"all\"} " <> mshow (_pSuccesses _pRelays) <> "\n# pRelays_pSuccesses\n\
      \popopx_smp_relay_sessions_successes{source=\"own\"} " <> mshow (_pSuccesses _pRelaysOwn) <> "\n# pRelaysOwn_pSuccesses\n\
      \\n\
      \# HELP popopx_smp_relay_sessions_errors Error session events through relay.\n\
      \# TYPE popopx_smp_relay_sessions_errors counter\n\
      \popopx_smp_relay_sessions_errors{source=\"all\",type=\"connect\"} " <> mshow (_pErrorsConnect _pRelays) <> "\n# pRelays_pErrorsConnect\n\
      \popopx_smp_relay_sessions_errors{source=\"all\",type=\"compat\"} " <> mshow (_pErrorsCompat _pRelays) <> "\n# pRelays_pErrorsCompat\n\
      \popopx_smp_relay_sessions_errors{source=\"all\",type=\"other\"} " <> mshow (_pErrorsOther _pRelays) <> "\n# pRelays_pErrorsOther\n\
      \popopx_smp_relay_sessions_errors{source=\"own\",type=\"connect\"} " <> mshow (_pErrorsConnect _pRelaysOwn) <> "\n# pRelaysOwn_pErrorsConnect\n\
      \popopx_smp_relay_sessions_errors{source=\"own\",type=\"compat\"} " <> mshow (_pErrorsCompat _pRelaysOwn) <> "\n# pRelaysOwn_pErrorsCompat\n\
      \popopx_smp_relay_sessions_errors{source=\"own\",type=\"other\"} " <> mshow (_pErrorsOther _pRelaysOwn) <> "\n# pRelaysOwn_pErrorsOther\n\
      \\n\
      \# HELP popopx_smp_relay_messages_requests Message requests sent through relay.\n\
      \# TYPE popopx_smp_relay_messages_requests counter\n\
      \popopx_smp_relay_messages_requests{source=\"all\"} " <> mshow (_pRequests _pMsgFwds) <> "\n# pMsgFwds_pRequests\n\
      \popopx_smp_relay_messages_requests{source=\"own\"} " <> mshow (_pRequests _pMsgFwdsOwn) <> "\n# pMsgFwdsOwn_pRequests\n\
      \\n\
      \# HELP popopx_smp_relay_messages_successes Successful messages sent through relay.\n\
      \# TYPE popopx_smp_relay_messages_successes counter\n\
      \popopx_smp_relay_messages_successes{source=\"all\"} " <> mshow (_pSuccesses _pMsgFwds) <> "\n# pMsgFwds_pSuccesses\n\
      \popopx_smp_relay_messages_successes{source=\"own\"} " <> mshow (_pSuccesses _pMsgFwdsOwn) <> "\n# pMsgFwdsOwn_pSuccesses\n\
      \\n\
      \# HELP popopx_smp_relay_messages_errors Error events with messages sent through relay.\n\
      \# TYPE popopx_smp_relay_messages_errors counter\n\
      \popopx_smp_relay_messages_errors{source=\"all\",type=\"connect\"} " <> mshow (_pErrorsConnect _pMsgFwds) <> "\n# pMsgFwds_pErrorsConnect\n\
      \popopx_smp_relay_messages_errors{source=\"all\",type=\"compat\"} " <> mshow (_pErrorsCompat _pMsgFwds) <> "\n# pMsgFwds_pErrorsCompat\n\
      \popopx_smp_relay_messages_errors{source=\"all\",type=\"other\"} " <> mshow (_pErrorsOther _pMsgFwds) <> "\n# pMsgFwds_pErrorsOther\n\
      \popopx_smp_relay_messages_errors{source=\"own\",type=\"connect\"} " <> mshow (_pErrorsConnect _pMsgFwdsOwn) <> "\n# pMsgFwdsOwn_pErrorsConnect\n\
      \popopx_smp_relay_messages_errors{source=\"own\",type=\"compat\"} " <> mshow (_pErrorsCompat _pMsgFwdsOwn) <> "\n# pMsgFwdsOwn_pErrorsCompat\n\
      \popopx_smp_relay_messages_errors{source=\"own\",type=\"other\"} " <> mshow (_pErrorsOther _pMsgFwdsOwn) <> "\n# pMsgFwdsOwn_pErrorsOther\n\
      \\n\
      \# HELP popopx_smp_relay_messages_received Relay messages statistics.\n\
      \# TYPE popopx_smp_relay_messages_received counter\n\
      \popopx_smp_relay_messages_received " <> mshow _pMsgFwdsRecv <> "\n# pMsgFwdsRecv\n\
      \\n"
    services =
      "# Services\n\
      \# --------\n\
      \# HELP popopx_smp_rcv_services_count The count of receiving services.\n\
      \# TYPE popopx_smp_rcv_services_count gauge\n\
      \popopx_smp_rcv_services_count " <> mshow (rcvServiceCount entityCounts) <> "\n# rcvServiceCount\n\
      \\n\
      \# HELP popopx_smp_rcv_services_queues_count The count of queues associated with receiving services.\n\
      \# TYPE popopx_smp_rcv_services_queues_count gauge\n\
      \popopx_smp_rcv_services_queues_count " <> mshow (rcvServiceQueuesCount entityCounts) <> "\n# rcv.rcvServiceQueuesCount\n\
      \\n\
      \# HELP popopx_smp_ntf_services_count The count of notification services.\n\
      \# TYPE popopx_smp_ntf_services_count gauge\n\
      \popopx_smp_ntf_services_count " <> mshow (ntfServiceCount entityCounts) <> "\n# ntfServiceCount\n\
      \\n\
      \# HELP popopx_smp_ntf_services_queues_count The count of queues associated with notification services.\n\
      \# TYPE popopx_smp_ntf_services_queues_count gauge\n\
      \popopx_smp_ntf_services_queues_count " <> mshow (ntfServiceQueuesCount entityCounts) <> "\n# ntfServiceQueuesCount\n\
      \\n\
      \# HELP popopx_smp_rcv_services_sub_msg_count The count of subscribed service queues with messages.\n\
      \# TYPE popopx_smp_rcv_services_sub_msg_count counter\n\
      \popopx_smp_rcv_services_sub_msg_count " <> mshow _rcvServicesSubMsg <> "\n# rcvServicesSubMsg\n\
      \\n\
      \# HELP popopx_smp_rcv_services_sub_duplicate_count The count of duplicate subscribed service queues.\n\
      \# TYPE popopx_smp_rcv_services_sub_duplicate_count counter\n\
      \popopx_smp_rcv_services_sub_duplicate_count " <> mshow _rcvServicesSubDuplicate <> "\n# rcvServicesSubDuplicate\n\
      \\n"
        <> showServices _rcvServices "rcv" "receiving"
        <> showServices _ntfServices "ntf" "notification"
    showServices ss pfx name =
      "# HELP popopx_smp_" <> pfx <> "_services_assoc_new New queue associations with " <> name <> " services.\n\
      \# TYPE popopx_smp_" <> pfx <> "_services_assoc_new counter\n\
      \popopx_smp_" <> pfx <> "_services_assoc_new " <> mshow (_srvAssocNew ss) <> "\n# " <> pfx <> ".srvAssocNew\n\
      \\n\
      \# HELP popopx_smp_" <> pfx <> "_services_assoc_duplicate Duplicate queue associations with " <> name <> " services.\n\
      \# TYPE popopx_smp_" <> pfx <> "_services_assoc_duplicate counter\n\
      \popopx_smp_" <> pfx <> "_services_assoc_duplicate " <> mshow (_srvAssocDuplicate ss) <> "\n# " <> pfx <> ".srvAssocDuplicate\n\
      \\n\
      \# HELP popopx_smp_" <> pfx <> "_services_assoc_updated Updated queue associations with " <> name <> " services.\n\
      \# TYPE popopx_smp_" <> pfx <> "_services_assoc_updated counter\n\
      \popopx_smp_" <> pfx <> "_services_assoc_updated " <> mshow (_srvAssocUpdated ss) <> "\n# " <> pfx <> ".srvAssocUpdated\n\
      \\n\
      \# HELP popopx_smp_" <> pfx <> "_services_assoc_removed Removed queue associations with " <> name <> " services.\n\
      \# TYPE popopx_smp_" <> pfx <> "_services_assoc_removed counter\n\
      \popopx_smp_" <> pfx <> "_services_assoc_removed " <> mshow (_srvAssocRemoved ss) <> "\n# " <> pfx <> ".srvAssocRemoved\n\
      \\n\
      \# HELP popopx_smp_" <> pfx <> "_services_sub_count Service subscriptions by " <> name <> " services.\n\
      \# TYPE popopx_smp_" <> pfx <> "_services_sub_count counter\n\
      \popopx_smp_" <> pfx <> "_services_sub_count " <> mshow (_srvSubCount ss) <> "\n# " <> pfx <> ".srvSubCount\n\
      \\n\
      \# HELP popopx_smp_" <> pfx <> "_services_sub_duplicate Duplicate service subscriptions by " <> name <> " services.\n\
      \# TYPE popopx_smp_" <> pfx <> "_services_sub_duplicate counter\n\
      \popopx_smp_" <> pfx <> "_services_sub_duplicate " <> mshow (_srvSubDuplicate ss) <> "\n# " <> pfx <> ".srvSubDuplicate\n\
      \\n\
      \# HELP popopx_smp_" <> pfx <> "_services_sub_queues Queues subscribed by " <> name <> " services.\n\
      \# TYPE popopx_smp_" <> pfx <> "_services_sub_queues gauge\n\
      \popopx_smp_" <> pfx <> "_services_sub_queues " <> mshow (_srvSubQueues ss) <> "\n# " <> pfx <> ".srvSubQueues\n\
      \\n\
      \# HELP popopx_smp_" <> pfx <> "_services_sub_end Ended subscriptions with " <> name <> " services.\n\
      \# TYPE popopx_smp_" <> pfx <> "_services_sub_end gauge\n\
      \popopx_smp_" <> pfx <> "_services_sub_end " <> mshow (_srvSubEnd ss) <> "\n# " <> pfx <> ".srvSubEnd\n\
      \\n\
      \# HELP popopx_smp_" <> pfx <> "_services_sub_ok Service subscriptions for " <> name <> " services.\n\
      \# TYPE popopx_smp_" <> pfx <> "_services_sub_ok gauge\n\
      \popopx_smp_" <> pfx <> "_services_sub_ok " <> mshow (_srvSubOk ss) <> "\n# " <> pfx <> ".srvSubOk\n\
      \\n\
      \# HELP popopx_smp_" <> pfx <> "_services_sub_more Service subscriptions for " <> name <> " services with more queues than in the client.\n\
      \# TYPE popopx_smp_" <> pfx <> "_services_sub_more gauge\n\
      \popopx_smp_" <> pfx <> "_services_sub_more " <> mshow (_srvSubMore ss) <> "\n# " <> pfx <> ".srvSubMore\n\
      \\n\
      \# HELP popopx_smp_" <> pfx <> "_services_sub_fewer Service subscriptions for " <> name <> " services with fewer queues than in the client.\n\
      \# TYPE popopx_smp_" <> pfx <> "_services_sub_fewer gauge\n\
      \popopx_smp_" <> pfx <> "_services_sub_fewer " <> mshow (_srvSubFewer ss) <> "\n# " <> pfx <> ".srvSubFewer\n\
      \\n\
      \# HELP popopx_smp_" <> pfx <> "_services_sub_diff Service subscriptions for " <> name <> " services with different hash than in the client.\n\
      \# TYPE popopx_smp_" <> pfx <> "_services_sub_diff gauge\n\
      \popopx_smp_" <> pfx <> "_services_sub_diff " <> mshow (_srvSubDiff ss) <> "\n# " <> pfx <> ".srvSubDiff\n\
      \\n\
      \# HELP popopx_smp_" <> pfx <> "_services_sub_more_total Service subscriptions for " <> name <> " services with more queues than in the client total.\n\
      \# TYPE popopx_smp_" <> pfx <> "_services_sub_more_total gauge\n\
      \popopx_smp_" <> pfx <> "_services_sub_more_total " <> mshow (_srvSubMoreTotal ss) <> "\n# " <> pfx <> ".srvSubMoreTotal\n\
      \\n\
      \# HELP popopx_smp_" <> pfx <> "_services_sub_fewer_total Service subscriptions for " <> name <> " services with fewer queues than in the client total.\n\
      \# TYPE popopx_smp_" <> pfx <> "_services_sub_fewer_total gauge\n\
      \popopx_smp_" <> pfx <> "_services_sub_fewer_total " <> mshow (_srvSubFewerTotal ss) <> "\n# " <> pfx <> ".srvSubFewerTotal\n\
      \\n"
    names =
      let NameResolverStatsData {_rslvReqs, _rslvSucc, _rslvNotFound, _rslvResolverErrs, _rslvDisabled} = _rslvStats
       in "# Names\n\
          \# -----\n\
          \\n\
          \# HELP popopx_smp_names_reqs Total RSLV requests forwarded to this server.\n\
          \# TYPE popopx_smp_names_reqs counter\n\
          \popopx_smp_names_reqs " <> mshow _rslvReqs <> "\n# rslvReqs\n\
          \\n\
          \# HELP popopx_smp_names_success NameRecord resolved, or availability answered.\n\
          \# TYPE popopx_smp_names_success counter\n\
          \popopx_smp_names_success " <> mshow _rslvSucc <> "\n# rslvSucc\n\
          \\n\
          \# HELP popopx_smp_names_not_found Answers a client below v22 reads as NOT_FOUND.\n\
          \# TYPE popopx_smp_names_not_found counter\n\
          \popopx_smp_names_not_found " <> mshow _rslvNotFound <> "\n# rslvNotFound\n\
          \\n\
          \# HELP popopx_smp_names_resolver_errs Resolver backend errors (HTTP 5xx, transport, decode, or timeout).\n\
          \# TYPE popopx_smp_names_resolver_errs counter\n\
          \popopx_smp_names_resolver_errs " <> mshow _rslvResolverErrs <> "\n# rslvResolverErrs\n\
          \\n\
          \# HELP popopx_smp_names_disabled RSLV requests rejected because no resolver is configured (names role off).\n\
          \# TYPE popopx_smp_names_disabled counter\n\
          \popopx_smp_names_disabled " <> mshow _rslvDisabled <> "\n# rslvDisabled\n\
          \\n"
    info =
      "# Info\n\
      \# ----\n\
      \\n\
      \# HELP popopx_smp_info Server information. RTS options have to be passed via " <> rtsOptionsEnv <> " env var\n\
      \# TYPE popopx_smp_info gauge\n\
      \popopx_smp_info{version=\"" <> T.pack popopxMQVersion <> "\",rts_options=\"" <> rtsOptions <> "\"} 1\n\
      \\n"
      <> socketsMetric socketsAccepted "popopx_smp_sockets_accepted" "Accepted sockets"
      <> socketsMetric socketsClosed "popopx_smp_sockets_closed" "Closed sockets"
      <> socketsMetric socketsActive "popopx_smp_sockets_active" "Active sockets"
      <> socketsMetric socketsLeaked "popopx_smp_sockets_leaked" "Leaked sockets"
      <> "# HELP popopx_smp_threads_total Threads\n\
      \# TYPE popopx_smp_threads_total gauge\n\
      \popopx_smp_threads_total " <> mshow threadsCount <> "\n\
      \\n\
      \# HELP popopx_smp_clients_total Clients\n\
      \# TYPE popopx_smp_clients_total gauge\n\
      \popopx_smp_clients_total " <> mshow clientsCount <> "\n\
      \\n\
      \# HELP popopx_smp_delivered_total Total SMP subscriptions with delivered messages\n\
      \# TYPE popopx_smp_delivered_total gauge\n\
      \popopx_smp_delivered_total " <> mshow (subsCount deliveredSubs) <> "\n# delivered.subsCount\n\
      \\n\
      \# HELP popopx_smp_delivered_clients_total Subscribed clients\n\
      \# TYPE popopx_smp_delivered_clients_total gauge\n\
      \popopx_smp_delivered_clients_total " <> mshow (subClientsCount deliveredSubs) <> "\n# delivered.subClientsCount\n\
      \\n\
      \# HELP popopx_smp_delivery_ack_confirmed_time Times to confirm message delivery, only confirmed deliveries\n\
      \# TYPE popopx_smp_delivery_ack_confirmed_time histogram\n\
      \popopx_smp_delivery_ack_confirmed_time_sum " <> mshow (sumTime _msgRecvAckTimes) <> "\n\
      \popopx_smp_delivery_ack_confirmed_time_count " <> mshow (_msgRecv + _msgRecvGet) <> "\n"
      <> showTimeBuckets "popopx_smp_delivery_ack_confirmed_time" (timeBuckets _msgRecvAckTimes)
      <> showTimeBucket "popopx_smp_delivery_ack_confirmed_time" "+Inf" (_msgRecv + _msgRecvGet)
      <> "\n\
      \# HELP popopx_smp_delivery_ack_confirmed_count Counts for confirmed deliveries\n\
      \# TYPE popopx_smp_delivery_ack_confirmed_count counter\n"
      <> showBucketSums "popopx_smp_delivery_ack_confirmed_count" (timeBuckets _msgRecvAckTimes)
      <> "\n\
      \# HELP popopx_smp_delivery_ack_pending_count Counts for pending delivery\n\
      \# TYPE popopx_smp_delivery_ack_pending_count gauge\n"
      <> showBucketSums "popopx_smp_delivery_ack_pending_count" (timeBuckets deliveredTimes)
      <> "\n\
      \# HELP popopx_smp_delivery_ack_time_max Max time to confirm message delivery\n\
      \# TYPE popopx_smp_delivery_ack_time_max gauge\n\
      \popopx_smp_delivery_ack_time_max " <> mshow (maxTime deliveredTimes) <> "\n# delivered.maxTime\n\
      \\n\
      \# HELP popopx_smp_subscribtion_total Total SMP subscriptions\n\
      \# TYPE popopx_smp_subscribtion_total gauge\n\
      \popopx_smp_subscribtion_total " <> mshow (subsCount smpSubs) <> "\n# smp.subsCount\n\
      \\n\
      \# HELP popopx_smp_subscribtion_clients_total Subscribed clients\n\
      \# TYPE popopx_smp_subscribtion_clients_total gauge\n\
      \popopx_smp_subscribtion_clients_total " <> mshow (subClientsCount smpSubs) <> "\n# smp.subClientsCount\n\
      \\n\
      \# HELP popopx_smp_subscribtion_services_total Subscribed services, first counting method\n\
      \# TYPE popopx_smp_subscribtion_services_total gauge\n\
      \popopx_smp_subscribtion_services_total " <> mshow (subServicesCount smpSubs) <> "\n# smp.subServicesCount\n\
      \\n\
      \# HELP popopx_smp_subscribtion_service_subs_total Total queues subscribed via services\n\
      \# TYPE popopx_smp_subscribtion_service_subs_total gauge\n\
      \popopx_smp_subscribtion_service_subs_total " <> mshow (subServiceSubsCount smpSubs) <> "\n# smp.subServiceSubsCount\n\
      \\n\
      \# HELP popopx_smp_subscription_ntf_total Total notification subscripbtions (from ntf server)\n\
      \# TYPE popopx_smp_subscription_ntf_total gauge\n\
      \popopx_smp_subscription_ntf_total " <> mshow (subsCount ntfSubs) <> "\n# ntf.subsCount\n\
      \\n\
      \# HELP popopx_smp_subscription_ntf_clients_total Total subscribed NTF servers\n\
      \# TYPE popopx_smp_subscription_ntf_clients_total gauge\n\
      \popopx_smp_subscription_ntf_clients_total " <> mshow (subClientsCount ntfSubs) <> "\n# ntf.subClientsCount\n\
      \\n\
      \# HELP popopx_smp_subscribtion_nts_services_total Subscribed NTF services, first counting method\n\
      \# TYPE popopx_smp_subscribtion_nts_services_total gauge\n\
      \popopx_smp_subscribtion_nts_services_total " <> mshow (subServicesCount ntfSubs) <> "\n# ntf.subServicesCount\n\
      \\n\
      \# HELP popopx_smp_subscription_ntf_service_subs_total Total queues subscribed via NTF services\n\
      \# TYPE popopx_smp_subscription_ntf_service_subs_total gauge\n\
      \popopx_smp_subscription_ntf_service_subs_total " <> mshow (subServiceSubsCount ntfSubs) <> "\n# ntf.subServiceSubsCount\n\
      \\n\
      \# HELP popopx_smp_loaded_queues_queue_count Total loaded queues count (all queues for memory storage)\n\
      \# TYPE popopx_smp_loaded_queues_queue_count gauge\n\
      \popopx_smp_loaded_queues_queue_count " <> mshow (loadedQueueCount loadedCounts) <> "\n# loadedCounts.loadedQueueCount\n\
      \\n\
      \# HELP popopx_smp_loaded_queues_ntf_count Total loaded ntf credential references (all ntf credentials for memory storage)\n\
      \# TYPE popopx_smp_loaded_queues_ntf_count gauge\n\
      \popopx_smp_loaded_queues_ntf_count " <> mshow (loadedNotifierCount loadedCounts) <> "\n# loadedCounts.loadedNotifierCount\n"

    showTimeBuckets :: Text -> IM.IntMap Int -> Text
    showTimeBuckets metric = T.concat . snd . mapAccumL accumBucket (0, 0) . IM.assocs
      where
        accumBucket (prevSec, total) (sec, cnt) =
          let t
                | sec - 60 > prevSec = showTimeBucket metric (tshow (sec - 60)) total
                | otherwise = ""
           in ((sec, total + cnt), t <> showTimeBucket metric (tshow sec) (total + cnt))
    showTimeBucket :: Text -> Text -> Int -> Text
    showTimeBucket metric sec count = metric <> "_bucket{le=\"" <> sec <> "\"} " <> mshow count <> "\n"
    showBucketSums :: Text -> IM.IntMap Int -> Text
    showBucketSums metric buckets = T.concat $ map showBucketSum [(0, 60), (60, 300), (300, 1200), (1200, 3600), (3600, maxBound)]
      where
        showBucketSum (minTime, maxTime) =
          metric <> "{period=\"" <> tshow minTime <> (if maxTime <= 3600 then "-" <> tshow maxTime else "+") <> "\"} " <> mshow bucketsSum <> "\n"
          where
            bucketsSum = IM.foldl' (+) 0 $ IM.filter (\sec -> minTime <= sec && sec < maxTime) buckets
    socketsMetric :: (SocketStats -> Int) -> Text -> Text -> Text
    socketsMetric sel metric descr =
      "# HELP " <> metric <> " " <> descr <> "\n"
        <> "# TYPE " <> metric <> " gauge\n"
        <> T.concat (map (\(port, ss) -> metric <> "{port=\"" <> T.pack port <> "\"} " <> mshow (sel ss) <> "\n") socketStats)
        <> "\n"
    mstr a = a <> " " <> tsEpoch ts
    mshow :: Show a => a -> Text
    mshow = mstr . tshow
    tsEpoch t = tshow @Int64 $ floor @Double $ realToFrac (t `diffUTCTime` epoch) * 1000
    epoch = UTCTime systemEpochDay 0
{-# FOURMOLU_ENABLE\n#-}
