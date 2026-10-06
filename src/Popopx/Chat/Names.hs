-- Original Work Copyright (C) 2020-2022 simplex.chat
--
-- --- MODIFICATION NOTICE (AGPL v3 Section 5.a) ---
-- This file was modified by POPOPX Team in 2026.
-- Changes: Rebranded from SimpleX Chat to POPOPX Chat.

{-# LANGUAGE CPP #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE KindSignatures #-}
{-# LANGUAGE NamedFieldPuns #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TemplateHaskell #-}

module Popopx.Chat.Names
  ( PopopxDomainClaim (..),
    PopopxDomainProof (..),
    mkDomainClaim,
    claimDomain,
  )
where

import qualified Data.Aeson.TH as JQ
import Popopx.Chat.Badges (ProofPresHeader)
import Popopx.Messaging.Agent.Protocol (OwnerId, PopopxDomain)
import Popopx.Messaging.Agent.Store.DB (fromTextField_)
import qualified Popopx.Messaging.Crypto as C
import Popopx.Messaging.Encoding.String
import Popopx.Messaging.Parsers (defaultJSON)
import Popopx.Messaging.Util (decodeJSON, encodeJSON)
#if defined(dbPostgres)
import Database.PostgreSQL.Simple.FromField (FromField (..))
import Database.PostgreSQL.Simple.ToField (ToField (..))
#else
import Database.SQLite.Simple.FromField (FromField (..))
import Database.SQLite.Simple.ToField (ToField (..))
#endif

-- A name claim proof: signed by the address owner's key over proof payload - see verifyDomainProof.
data PopopxDomainProof = PopopxDomainProof
  { linkOwnerId :: Maybe (StrJSON "OwnerId" OwnerId),
    presHeader :: ProofPresHeader,
    signature :: C.Signature 'C.Ed25519
  }
  deriving (Eq, Show)

$(JQ.deriveJSON defaultJSON ''PopopxDomainProof)

instance ToField PopopxDomainProof where toField = toField . encodeJSON

instance FromField PopopxDomainProof where fromField = fromTextField_ decodeJSON

data PopopxDomainClaim = PopopxDomainClaim
  { domain :: StrJSON "PopopxDomain" PopopxDomain,
    proof :: Maybe PopopxDomainProof
  }
  deriving (Eq, Show)

mkDomainClaim :: PopopxDomain -> PopopxDomainClaim
mkDomainClaim = (`PopopxDomainClaim` Nothing) . StrJSON

claimDomain :: PopopxDomainClaim -> PopopxDomain
claimDomain (PopopxDomainClaim n _) = unStrJSON n

$(JQ.deriveJSON defaultJSON ''PopopxDomainClaim)
