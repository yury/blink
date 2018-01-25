

#import "Session.h"
#import "TermDevice.h"

#define UNICODE_REPLACEMENT_CHAR 0xffdf

// Returns the number of valid bytes in a sequence from a row in table 3-7 of the Unicode 6.2 spec.
// Returns 0 if no bytes are valid (a true maximal subpart is never less than 1).
static int maximal_subpart_of_row(const unsigned char *datap,
                                  int datalen,
                                  int bytesInRow,
                                  int *min,  // array of min values, with |bytesInRow| elements.
                                  int *max)  // array of max values, with |bytesInRow| elements.
{
  for (int i = 0; i < bytesInRow && i < datalen; i++) {
    const int v = datap[i];
    if (v < min[i] || v > max[i]) {
      return i;
    }
  }
  return bytesInRow;
}

// This function finds the longest initial sequence of bytes that look like a valid UTF-8 sequence.
// It's used to gobble them up and replace them with a <?> replacement mark in an invalid sequence.
static int minimal_subpart(const unsigned char *datap, int datalen)
{
  // This comes from table 3-7 in http://www.unicode.org/versions/Unicode6.2.0/ch03.pdf
  struct {
    int numBytes;  // Num values in min, max arrays
    int min[4];    // Minimum values for each byte in a utf-8 sequence.
    int max[4];    // Max values.
  } wellFormedSequencesTable[] = {
    {
      1,
      { 0x00, -1, -1, -1, },
      { 0x7f, -1, -1, -1, },
    },
    {
      2,
      { 0xc2, 0x80, -1, -1, },
      { 0xdf, 0xbf, -1, -1 },
    },
    {
      3,
      { 0xe0, 0xa0, 0x80, -1, },
      { 0xe0, 0xbf, 0xbf, -1 },
    },
    {
      3,
      { 0xe1, 0x80, 0x80, -1, },
      { 0xec, 0xbf, 0xbf, -1, },
    },
    {
      3,
      { 0xed, 0x80, 0x80, -1, },
      { 0xed, 0x9f, 0xbf, -1 },
    },
    {
      3,
      { 0xee, 0x80, 0x80, -1, },
      { 0xef, 0xbf, 0xbf, -1, },
    },
    {
      4,
      { 0xf0, 0x90, 0x80, -1, },
      { 0xf0, 0xbf, 0xbf, -1, },
    },
    {
      4,
      { 0xf1, 0x80, 0x80, 0x80, },
      { 0xf3, 0xbf, 0xbf, 0xbf, },
    },
    {
      4,
      { 0xf4, 0x80, 0x80, 0x80, },
      { 0xf4, 0x8f, 0xbf, 0xbf },
    },
    { -1, { -1 }, { -1 } }
  };
  
  int longest = 0;
  for (int row = 0; wellFormedSequencesTable[row].numBytes > 0; row++) {
    longest = MAX(longest,
                  maximal_subpart_of_row(datap,
                                         datalen,
                                         wellFormedSequencesTable[row].numBytes,
                                         wellFormedSequencesTable[row].min,
                                         wellFormedSequencesTable[row].max));
  }
  return MIN(datalen, MAX(1, longest));
}

int decode_utf8_char(const unsigned char *datap,
                     int datalen,
                     int * restrict result)
{
  unsigned int theChar;
  int utf8Length;
  unsigned char c;
  // This maps a utf-8 sequence length to the smallest code point it should
  // encode (e.g., using 5 bytes to encode an ascii character would be
  // considered an error).
  unsigned int smallest[7] = { 0, 0, 0x80UL, 0x800UL, 0x10000UL, 0x200000UL, 0x4000000UL };
  
  if (datalen == 0) {
    return 0;
  }
  
  c = *datap;
  if ((c & 0x80) == 0x00) {
    *result = c;
    return 1;
  } else if ((c & 0xE0) == 0xC0) {
    theChar = c & 0x1F;
    utf8Length = 2;
  } else if ((c & 0xF0) == 0xE0) {
    theChar = c & 0x0F;
    utf8Length = 3;
  } else if ((c & 0xF8) == 0xF0) {
    theChar = c & 0x07;
    utf8Length = 4;
  } else if ((c & 0xFC) == 0xF8) {
    theChar = c & 0x03;
    utf8Length = 5;
  } else if ((c & 0xFE) == 0xFC) {
    theChar = c & 0x01;
    utf8Length = 6;
  } else {
    return -1;
  }
  for (int i = 1; i < utf8Length; i++) {
    if (datalen <= i) {
      return 0;
    }
    c = datap[i];
    if ((c & 0xc0) != 0x80) {
      // Expected a continuation character but did not get one.
      return -i;
    }
    theChar = (theChar << 6) | (c & 0x3F);
  }
  
  if (theChar < smallest[utf8Length]) {
    // A too-long sequence was used to encode a value. For example, a 4-byte sequence must encode
    // a value of at least 0x10000 (it is F0 90 80 80). A sequence like F0 8F BF BF is invalid
    // because there is a 3-byte sequence to encode U+FFFF (the sequence is EF BF BF).
    return -minimal_subpart(datap, datalen);
  }
  
  // Reject UTF-16 surrogates. They are invalid UTF-8 sequences.
  // Reject characters above U+10FFFF, as they are also invalid UTF-8 sequences.
  if ((theChar >= 0xD800 && theChar <= 0xDFFF) || theChar > 0x10FFFF) {
    return -minimal_subpart(datap, datalen);
  }
  
  *result = (int)theChar;
  return utf8Length;
}

// The TermStream is the PTYDevice
// They might actually be different. The Device listens, the stream is lower level.
// The PTY never listens. The Device or Wigdget is a way to indicate that
@implementation TermDevice {
  // Initialized from stream, and make the stream duplicate itself.
  // The stream then has access to the "device" or "widget"
  // The Widget then has functions to read from the stream and pass it.
  int _pinput[2];
  int _poutput[2];
  int _perror[2];
  struct winsize *_termsz;
  dispatch_io_t _channel;
  dispatch_data_t _splitChar;
}

// Creates descriptors
// NO. This should be part of the control. Opens / runs a session on a pty device
//   When creating the session, we pass it the descriptors
// Manages master / slave transparently between the descriptors.
// Replaces fterm
// Signals here too instead of in TermController? Signals might depend on the Session though. How is this done in real UNIX? How is the signal sent to the process if the pty knows nothing?

// TODO: Temporary fix, get rid of the control in the Stream?
// This smells like the Device will have to implement this functions, wrapping the Widget. Wait and see...
- (void)setControl:(TermController *)control
{
  _control = control;
  _stream.control = control;
}

- (id)init
{
  self = [super init];
  
  if (self) {
    if (pipe(_pinput) < 0) {
      NSLog(@"Error: failed to create _pinput pipe");
    }
    if (pipe(_poutput) < 0) {
      NSLog(@"Error: failed to create _poutput pipe");
    }
    if (pipe(_perror) < 0) {
      NSLog(@"Error: failed to create _perror pipe");
    }
    
    // TODO: Change the interface
    // Initialize on the stream
    _stream = [[TermStream alloc] init];
    _stream.in = fdopen(_pinput[0], "r");
    _stream.out = fdopen(_poutput[1], "w");
    _stream.err = fdopen(_perror[1], "w");
    setvbuf(_stream.out, NULL, _IONBF, 0);
    setvbuf(_stream.err, NULL, _IONBF, 0);
    setvbuf(_stream.in, NULL, _IONBF, 0);
    
    // TODO: Can we take the size outside the stream too?
    // Although in some way the size should belong to the pty.
    _termsz = malloc(sizeof(struct winsize));
    _stream.sz = _termsz;
    
    // Create channel with a callback
    dispatch_queue_t queue;
    queue = dispatch_queue_create("com.example.MyQueue", NULL);
    
    _channel = dispatch_io_create(DISPATCH_IO_STREAM, _poutput[0],
                                  queue,
                                  ^(int error) {
                                    printf("Error creating channel");
                                    
                                  });
    
    dispatch_io_set_low_water(_channel, 1);
    //dispatch_io_set_high_water(_channel, SIZE_MAX);
    // TODO: Get read of the main queue on TermView write. It will always happen here.

    dispatch_io_read(_channel, 0, SIZE_MAX, queue,
                     ^(bool done, dispatch_data_t data, int error) {
                       NSString *output = [self parseStream:data];
                       // TODO: Change to render
                       [_control.termView write:output];
                       
                       if (done) {
                         fprintf(stderr, "EOF encountered\n");
                         dispatch_io_close(_channel, 0);
                       }
                     });
    
  }
  
  return self;
}

- (NSString *)parseStream:(dispatch_data_t)data
{
  // TODO: Handle incomplete UTF sequences and other encodings
  if (_splitChar) {
    data = dispatch_data_create_concat(_splitChar, data);
    _splitChar = nil;
  }
  
  NSString *output;
  
  NSData *nsData = (NSData *)data;
  output = [[NSString alloc] initWithData:nsData encoding:NSUTF8StringEncoding];
  
  if (!output) {
    // Split char due to incomplete sequence
    
    size_t len = dispatch_data_get_size(data);
    char buffer[3];
    [nsData getBytes:&buffer length:MIN(3, len)];
    // Find the first UTF mark and compare with the iterator.
    int i = 1;
    for (; i <= ((len >= 3) ? 3 : len); i++) {
      unsigned char c = buffer[len - i];
      
      if (i == 1 && (c & 0x80) == 0) {
        // Single simple character, all good
        i=0;
        break;
      }
      
      // 10XXX XXXX
      if (c >> 6 == 0x02) {
        continue;
      }
      
      // Check if the character corresponds to the sequence by ORing with it
      if ((i == 2 && ((c | 0xDF) == 0xDF)) || // 110X XXXX 1 1101 1111
          (i == 3 && ((c | 0xEF) == 0xEF)) || // 1110 XXXX 2 1110 1111
          (i == 4 && ((c | 0xF7) == 0xF7))) { // 1111 0XXX 3 1111 0111
        // Complete sequence
        i=0;
        break;
      } else {
        // Save splitted sequences
        _splitChar = dispatch_data_create_subrange(data, len - i, i);
        // _splitChar = [data subdataWithRange:NSMakeRange(len - i, i)];
        break;
      }
    }
    
    printf("tweaking utf chars");
    output = [self UTF8Str:(NSData *)dispatch_data_create_subrange(data, 0, len - i)];//[[NSString alloc] initWithBytes:buffer length:(len - i) encoding:NSUTF8StringEncoding];
    
    //    if (!output) {
    //      output = [[NSString alloc] initWithBytes:buffer length:(len - i) encoding:NSASCIIStringEncoding];
    //    }
  }
  
  return output;
}

- (NSString *)UTF8Str:(NSData *)data {
  const unsigned char *p = data.bytes;
  int len = (int)data.length;
  int utf8DecodeResult;
  int theChar = 0;
  NSMutableData *utf16Data = [NSMutableData data];
  
  while (len > 0) {
    utf8DecodeResult = decode_utf8_char(p, len, &theChar);
    if (utf8DecodeResult == 0) {
      // Stop on end of stream.
      break;
    } else if (utf8DecodeResult < 0) {
      theChar = UNICODE_REPLACEMENT_CHAR;
      utf8DecodeResult = -utf8DecodeResult;
    } else if (theChar > 0xFFFF) {
      // Convert to surrogate pair.
      UniChar high, low;
      high = ((theChar - 0x10000) >> 10) + 0xd800;
      low = (theChar & 0x3ff) + 0xdc00;
      
      [utf16Data appendBytes:&high length:sizeof(high)];
      theChar = low;
    }
    
    UniChar c = theChar;
    [utf16Data appendBytes:&c length:sizeof(c)];
    
    p += utf8DecodeResult;
    len -= utf8DecodeResult;
  }
  
  return [[NSString alloc] initWithData:utf16Data encoding:NSUTF16LittleEndianStringEncoding];
}

- (void)write:(NSString *)input
{
  const char *str = [input UTF8String];
  write(_pinput[1], str, [input lengthOfBytesUsingEncoding:NSUTF8StringEncoding]);
}

- (void)close
{
  // TODO: Close the channel
  // TODO: Closing the streams!! But they are duplicated!!!!
  if (_stream) {
    [_stream close];
    _stream = nil;
  }

  if (_pinput[0]) {
    close(_pinput[0]);
    _pinput[0] = 0;
  }
  
  if (_pinput[1]) {
    close(_pinput[1]);
    _pinput[1] = 0;
  }
  
  if (_poutput[0]) {
    close(_poutput[0]);
    _poutput[0] = 0;
  }
  if (_poutput[1]) {
    close(_poutput[1]);
    _poutput[1] = 0;
  }
  
  if (_perror[0]) {
    close(_perror[0]);
    _perror[0] = 0;
  }
  
  if (_perror[1]) {
    close(_perror[1]);
    _perror[1] = 0;
  }
  
  if (_termsz) {
    free(_termsz);
    _termsz = NULL;
  }
}

- (void)dealloc
{
  [self close];
}

@end
