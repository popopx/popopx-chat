{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE NamedFieldPuns #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TypeApplications #-}
{-# OPTIONS_GHC -fno-warn-unrecognised-pragmas #-}

module Popopx.FileTransfer.Server.Prometheus
  ( FileServerMetrics (..),
    rtsOptionsEnv,
    xftpPrometheusMetrics,
  ) where

import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import Data.Time.Clock (UTCTime (..), diffUTCTime)
import Data.Time.Clock.System (systemEpochDay)
import Data.Time.Format.ISO8601 (iso8601Show)
import Popopx.FileTransfer.Server.Stats
import Popopx.Messaging.Server.Stats (PeriodStatCounts (..))
import Popopx.Messaging.Transport (popopxMQVersion)
import Popopx.Messaging.Util (tshow)

data FileServerMetrics = FileServerMetrics
  { statsData :: FileServerStatsData,
    filesDownloadedPeriods :: PeriodStatCounts,
    rtsOptions :: Text
  }

rtsOptionsEnv :: Text
rtsOptionsEnv = "XFTP_RTS_OPTIONS"

{-# FOURMOLU_DISABLE\n#-}
xftpPrometheusMetrics :: FileServerMetrics -> UTCTime -> Text
xftpPrometheusMetrics sm ts =
  time <> files <> info
  where
    FileServerMetrics {statsData, filesDownloadedPeriods, rtsOptions} = sm
    FileServerStatsData
      { _fromTime,
        _filesCreated,
        _fileRecipients,
        _filesUploaded,
        _filesExpired,
        _filesDeleted,
        _filesBlocked,
        _fileDownloads,
        _fileDownloadAcks,
        _filesCount,
        _filesSize
      } = statsData
    time =
      "# Recorded at: " <> T.pack (iso8601Show ts) <> "\n\
      \# Stats from: " <> T.pack (iso8601Show _fromTime) <> "\n\
      \\n"
    files =
      "# Files\n\
      \# -----\n\
      \\n\
      \# HELP popopx_xftp_files_created Created files\n\
      \# TYPE popopx_xftp_files_created counter\n\
      \popopx_xftp_files_created " <> mshow _filesCreated <> "\n\
      \# filesCreated\n\
      \\n\
      \# HELP popopx_xftp_files_recipients Files recipients\n\
      \# TYPE popopx_xftp_files_recipients counter\n\
      \popopx_xftp_files_recipients " <> mshow _fileRecipients <> "\n\
      \# fileRecipients\n\
      \\n\
      \# HELP popopx_xftp_files_uploaded Uploaded files\n\
      \# TYPE popopx_xftp_files_uploaded counter\n\
      \popopx_xftp_files_uploaded " <> mshow _filesUploaded <> "\n\
      \# filesUploaded\n\
      \\n\
      \# HELP popopx_xftp_files_expired Expired files\n\
      \# TYPE popopx_xftp_files_expired counter\n\
      \popopx_xftp_files_expired " <> mshow _filesExpired <> "\n\
      \# filesExpired\n\
      \\n\
      \# HELP popopx_xftp_files_deleted Deleted files\n\
      \# TYPE popopx_xftp_files_deleted counter\n\
      \popopx_xftp_files_deleted " <> mshow _filesDeleted <> "\n\
      \# filesDeleted\n\
      \\n\
      \# HELP popopx_xftp_files_blocked Blocked files\n\
      \# TYPE popopx_xftp_files_blocked counter\n\
      \popopx_xftp_files_blocked " <> mshow _filesBlocked <> "\n\
      \# filesBlocked\n\
      \\n\
      \# HELP popopx_xftp_file_downloads File downloads\n\
      \# TYPE popopx_xftp_file_downloads counter\n\
      \popopx_xftp_file_downloads " <> mshow _fileDownloads <> "\n\
      \# fileDownloads\n\
      \\n\
      \# HELP popopx_xftp_file_download_acks File download ACKs\n\
      \# TYPE popopx_xftp_file_download_acks counter\n\
      \popopx_xftp_file_download_acks " <> mshow _fileDownloadAcks <> "\n\
      \# fileDownloadAcks\n\
      \\n\
      \# HELP popopx_xftp_files_count_total Total files count \n\
      \# TYPE popopx_xftp_files_count_total gauge\n\
      \popopx_xftp_files_count_total " <> mshow _filesCount <> "\n\
      \# filesCount\n\
      \\n\
      \# HELP popopx_xftp_files_size Size of files \n\
      \# TYPE popopx_xftp_files_size gauge\n\
      \popopx_xftp_files_size " <> mshow _filesSize <> "\n\
      \# filesSize \n\
      \\n\
      \# HELP popopx_xftp_files_count_daily Daily files count\n\
      \# TYPE popopx_xftp_files_count_daily gauge\n\
      \popopx_xftp_files_count_daily " <> mstr (dayCount filesDownloadedPeriods) <> "\n\
      \# filesDownloaded.dayCount\n\
      \\n\
      \# HELP popopx_xftp_files_count_weekly Weekly files count\n\
      \# TYPE popopx_xftp_files_count_weekly gauge\n\
      \popopx_xftp_files_count_weekly " <> mstr (weekCount filesDownloadedPeriods) <> "\n\
      \# filesDownloaded.weekCount\n\
      \\n\
      \# HELP popopx_xftp_files_count_monthly Monthly files count\n\
      \# TYPE popopx_xftp_files_count_monthly gauge\n\
      \popopx_xftp_files_count_monthly " <> mstr (monthCount filesDownloadedPeriods) <> "\n\
      \# filesDownloaded.monthCount\n\
      \\n"
    info =
      "# Info\n\
      \# ----\n\
      \\n\
      \# HELP popopx_xftp_info Server information. RTS options have to be passed via " <> rtsOptionsEnv <> " env var\n\
      \# TYPE popopx_xftp_info gauge\n\
      \popopx_xftp_info{version=\"" <> T.pack popopxMQVersion <> "\",rts_options=\"" <> rtsOptions <> "\"} 1\n\
      \\n"
    mstr a = a <> " " <> tsEpoch
    mshow :: Show a => a -> Text
    mshow = mstr . tshow
    tsEpoch = tshow @Int64 $ floor @Double $ realToFrac (ts `diffUTCTime` epoch) * 1000
    epoch = UTCTime systemEpochDay 0
{-# FOURMOLU_ENABLE\n#-}
