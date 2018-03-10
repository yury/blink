////////////////////////////////////////////////////////////////////////////////
//
// B L I N K
//
// Copyright (C) 2016-2018 Blink Mobile Shell Project
//
// This file is part of Blink.
//
// Blink is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Blink is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Blink. If not, see <http://www.gnu.org/licenses/>.
//
// In addition, Blink is also subject to certain additional terms under
// GNU GPL version 3 section 7.
//
// You should have received a copy of these additional terms immediately
// following the terms and conditions of the GNU General Public License
// which accompanied the Blink Source Code. If not, see
// <http://www.github.com/blinksh/blink>.
//
////////////////////////////////////////////////////////////////////////////////

#ifndef TermJS_h
#define TermJS_h

static size_t extra_space(dispatch_data_t data)
{
  __block size_t result = 0;
  __block int iter = 0;
  dispatch_data_apply(data, ^bool(dispatch_data_t  _Nonnull region, size_t offset, const void * _Nonnull buffer, size_t size) {
    iter ++;
    const char * buf = buffer;
    for (size_t i = 0; i < size; i++ )
    {
      const char c = buf[i];
      switch (c)
      {
        case '"':
        case '\\':
        case '\b':
        case '\f':
        case '\n':
        case '\r':
        case '\t':
        {
          // from c (1 byte) to \x (2 bytes)
          result += 1;
          break;
        }
          
        default:
        {
          if (c >= 0x00 && c <= 0x1f)
          {
            // from c (1 byte) to \uxxxx (6 bytes)
            result += 5;
          }
          break;
        }
      }
    }
    return true;
  });
  
  return result;
}

static char* escape_string(dispatch_data_t data, size_t *newLen)
{
  size_t space = extra_space(data);
  if (space == 0)
  {
    return NULL;
  }
  
  size_t len = dispatch_data_get_size(data);
  *newLen = len + space;
  char * result = malloc(*newLen);
  memset(result, '\\', *newLen);
  __block size_t pos = 0;
  
  dispatch_data_apply(data, ^bool(dispatch_data_t  _Nonnull region, size_t offset, const void * _Nonnull buffer, size_t size) {
    const char * buf = buffer;
    
    for (size_t i = 0; i < size; i++)
    {
      char c = buf[i];
      switch (c)
      {
          // quotation mark (0x22)
        case '"':
        {
          result[pos + 1] = '"';
          pos += 2;
          break;
        }
          
          // reverse solidus (0x5c)
        case '\\':
        {
          // nothing to change
          pos += 2;
          break;
        }
          
          // backspace (0x08)
        case '\b':
        {
          result[pos + 1] = 'b';
          pos += 2;
          break;
        }
          
          // formfeed (0x0c)
        case '\f':
        {
          result[pos + 1] = 'f';
          pos += 2;
          break;
        }
          
          // newline (0x0a)
        case '\n':
        {
          result[pos + 1] = 'n';
          pos += 2;
          break;
        }
          
          // carriage return (0x0d)
        case '\r':
        {
          result[pos + 1] = 'r';
          pos += 2;
          break;
        }
          
          // horizontal tab (0x09)
        case '\t':
        {
          result[pos + 1] = 't';
          pos += 2;
          break;
        }
          
        default:
        {
          if (c >= 0x00 && c <= 0x1f)
          {
            // print character c as \uxxxx
            sprintf(&result[pos + 1], "u%04x", (UInt8)c);
            pos += 6;
            // overwrite trailing null character
            result[pos] = '\\';
          }
          else
          {
            // all other characters are added as-is
            result[pos++] = c;
          }
          break;
        }
      }
    }
    
    return true;
  });
  
  
  
  return result;
}

NSString *__encodeString(NSString *format, dispatch_data_t ddata)
{
  size_t newLen = 0;
  char *newBuff = escape_string(ddata, &newLen);
  NSString * res = nil;
  if (newBuff) {
    res = [[NSString alloc] initWithBytesNoCopy:newBuff length:newLen encoding:NSUTF8StringEncoding freeWhenDone:NO];
  } else {
    NSData *data = (NSData *)ddata;
    const char *buffer = [data bytes];
    size_t len = data.length;
    res = [[NSString alloc] initWithBytesNoCopy:buffer length:len encoding:NSUTF8StringEncoding freeWhenDone:NO];
  }
  
  NSString *cmd = [NSString stringWithFormat:format, res];
  
  if (newBuff) {
    free(newBuff);
  }
  return cmd;
}


NSString *_encodeString(NSString *str)
{
  NSData *jsonData = [NSJSONSerialization dataWithJSONObject:@[ str ] options:0 error:nil];
  return [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
}

NSString *term_init()
{
  return @"term_init();";
}

NSString *term_write(dispatch_data_t data) {
  return __encodeString(@"term_write(\"%@\");", data);
}

NSString *term_writeB64(NSData *data) {
  return [NSString stringWithFormat:@"term_write_b64(\"%@\");", [data base64EncodedStringWithOptions:kNilOptions]];
}

NSString *term_clear()
{
  return @"term_clear();";
}

NSString *term_reset()
{
  return @"term_reset();";
}

NSString *term_focus()
{
  return @"term_focus();";
}

NSString *term_blur()
{
  return @"term_blur();";
}

NSString *term_setWidth(NSInteger count)
{
  return [NSString stringWithFormat:@"term_setWidth(\"%ld\");", (long)count];
}

NSString *term_increaseFontSize()
{
  return @"term_increaseFontSize();";
}

NSString *term_decreaseFontSize()
{
  return @"term_decreaseFontSize();";
}

NSString *term_resetFontSize()
{
  return @"term_resetFontSize();";
}

NSString *term_scale(CGFloat scale)
{
  return [NSString stringWithFormat:@"term_scale(%f);", scale];
}

NSString *term_setFontSize(NSNumber *newSize)
{
  return [NSString stringWithFormat:@"term_setFontSize(\"%@\");", newSize];
}

NSString *term_getCurrentSelection()
{
  return @"term_getCurrentSelection();";
}

NSString *term_setCursorBlink(BOOL state)
{
  return [NSString stringWithFormat:@"term_set('cursor-blink', %@)", state ? @"true" : @"false"];
}

NSString *term_setBoldAsBright(BOOL state)
{
  return [NSString stringWithFormat:@"term_set('enable-bold-as-bright', %@)", state ? @"true" : @"false"];
}

NSString *term_setBoldEnabled(NSUInteger state)
{
  NSString *stateStr = @"null";
  if (state == 1) {
    stateStr = @"true";
  } else if (state == 2) {
    stateStr = @"false";
  }
  return [NSString stringWithFormat:@"term_set('enable-bold', %@)", stateStr];
}

NSString *term_setFontFamily(NSString *family)
{
  return [NSString stringWithFormat:@"term_setFontFamily(%@[0]);", _encodeString(family)];
}

NSString *term_appendUserCss(NSString *css)
{
  return [NSString stringWithFormat:@"term_appendUserCss(%@[0])", _encodeString(css)];
}

NSString *term_cleanSelection()
{
  return @"term_cleanSelection();";
}

NSString *term_modifySelection(NSString *direction, NSString *granularity)
{
  return [NSString stringWithFormat:@"term_modifySelection(%@[0], %@[0])", _encodeString(direction), _encodeString(granularity)];
}

NSString *term_setIme(NSString *imeText)
{
  return [NSString stringWithFormat:@"term_setIme(%@[0])", _encodeString(imeText)];
}

NSString *term_modifySideSelection()
{
  return @"term_modifySideSelection();";
}


#endif /* TermJS_h */
