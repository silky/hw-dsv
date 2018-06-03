{-# LANGUAGE BangPatterns        #-}
{-# LANGUAGE OverloadedStrings   #-}
{-# LANGUAGE ScopedTypeVariables #-}

module App.Commands.Query
  ( cmdQuery
  ) where

import App.Char
import App.Commands.Options.Type
import Control.Applicative
import Control.Lens
import Control.Monad
import Control.Monad.IO.Class       (liftIO)
import Control.Monad.Trans.Resource
import Data.Char                    (ord)
import Data.List
import Data.Semigroup               ((<>))
import Options.Applicative

import qualified App.IO                              as IO
import qualified App.Lens                            as L
import qualified Data.ByteString                     as BS
import qualified Data.ByteString.Builder             as B
import qualified Data.Vector                         as DV
import qualified HaskellWorks.Data.Dsv.Strict.Cursor as SVS

runQuery :: QueryOptions -> IO ()
runQuery opts = do
  c <- SVS.mmapCursor (opts ^. L.delimiter) (opts ^. L.useIndex) (opts ^. L.filePath)

  let !rows = SVS.toListVector c
  let !outDelimiterBuilder = B.word8 (fromIntegral (ord (opts ^. L.outDelimiter)))

  runResourceT $ do
    (_, hOut) <- IO.openOutputFile (opts ^. L.outputFilePath) Nothing
    forM_ rows $ \row -> do
      let fieldStrings = columnToFieldString row <$> (opts ^. L.columns)

      liftIO $ B.hPutBuilder hOut $ mconcat (intersperse outDelimiterBuilder fieldStrings) <> B.word8 10

      return ()
  return ()

  where columnToFieldString :: DV.Vector BS.ByteString -> Int -> B.Builder
        columnToFieldString fields i = if i >= 0 && i < DV.length fields
          then B.byteString (DV.unsafeIndex fields i)
          else B.byteString  BS.empty

cmdQuery :: Mod CommandFields (IO ())
cmdQuery = command "query" $ flip info idm $ runQuery <$> optsQuery

optsQuery :: Parser QueryOptions
optsQuery = QueryOptions
    <$> many
        ( option auto
          (   long "column"
          <>  short 'k'
          <>  help "Column to select"
          <>  metavar "COLUMN INDEX" ))
    <*> strOption
          (   long "input"
          <>  short 'i'
          <>  help "Input DSV file"
          <>  metavar "FILE"
          )
    <*> strOption
          (   long "output"
          <>  short 'o'
          <>  help "Output DSV file"
          <>  metavar "FILE"
          )
    <*> option readChar
          (   long "input-delimiter"
          <>  short 'd'
          <>  help "DSV delimiter to read in the input"
          <>  metavar "CHAR"
          )
    <*> option readChar
          (   long "output-delimiter"
          <>  short 'e'
          <>  help "DSV delimiter to write in the output"
          <>  metavar "CHAR"
          )
    <*> switch (long "use-index")
