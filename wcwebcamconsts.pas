unit wcwebcamconsts;

{$mode ObjFPC}{$H+}

interface

const STATE_INIT     = 0;
      STATE_FINISHED = 1;
      STATE_TERMINATED = 2;

      TASK_NO_ERROR = 0;
      TASK_ERROR_ATTACH_REQ = $10;
      TASK_ERROR_CANT_EASY_CURL = $11;
      TASK_ERROR_GET_INFO = $12;
      TASK_ERROR_CURL = $13;

      ERR_WEBCAM_STREAM_BUFFER_OVERFLOW = $21;
      ERR_WEBCAM_STREAM_FRAME_TO_BIG = $22;
      ERR_WEBCAM_STREAM_WRONG_HEADER = $23;


const WEBCAM_FRAME_START_SEQ : Word = $aaaa;
      WEBCAM_FRAME_HEADER_SIZE  = Sizeof(Word) + Sizeof(Cardinal);
      WEBCAM_FRAME_BUFFER_SIZE  = $200000;
      METH_GET = 0;
      METH_POST = 1;
      METH_UPLOAD = 2;

const cBAD = 'BAD';

      cMSG       = 'msg';
      cMSGS      = 'msgs';
      cRECORDS   = 'records';
      cRESULT    = 'result';
      cNAME      = 'name';
      cPASS      = 'pass';
      cSHASH     = 'shash';
      cMETA      = 'meta';
      cREC       = 'record';
      cSTAMP     = 'stamp';
      cRID       = 'rid';
      cMID       = 'mid';
      cSYNC      = 'sync';
      cDEVICE    = 'device';
      cDEVICES   = 'devices';
      cTARGET    = 'target';
      cPARAMS    = 'params';
      cCODE      = 'code';
      cCONFIG    = 'config';

const RESPONSE_ERRORS : Array [0..15] of String = (
                          'NO_ERROR',
                          'UNSPECIFIED',
                          'INTERNAL_UNKNOWN_ERROR',
                          'DATABASE_FAIL',
                          'JSON_PARSER_FAIL',
                          'JSON_FAIL',
                          'NO_SUCH_SESSION',
                          'NO_SUCH_USER',
                          'NO_DEVICES_ONLINE',
                          'NO_SUCH_RECORD',
                          'NO_DATA_RETURNED',
                          'EMPTY_REQUEST',
                          'MALFORMED_REQUEST',
                          'NO_CHANNEL',
                          'ERRORED_STREAM',
                          'NO_SUCH_DEVICE');

implementation

end.

