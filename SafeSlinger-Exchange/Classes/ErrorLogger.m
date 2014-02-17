/*
 * The MIT License (MIT)
 *
 * Copyright (c) 2010-2014 Carnegie Mellon University
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

#import "ErrorLogger.h"

#define ERRORLOGFILE @"%@/error.log"

@implementation ErrorLogger


+(void)ERRORDEBUG: (NSString*)message
{
    NSString* content = [NSString stringWithFormat:@"%@\n",message];
    
    //get the documents directory:
    NSArray *arr = [[NSArray alloc] initWithArray: NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES)];
	NSString* documentsPath = [arr objectAtIndex: 0];
    NSString *logfile = [NSString stringWithFormat: ERRORLOGFILE, documentsPath];
    
    NSFileHandle *fileHandle = [NSFileHandle fileHandleForWritingAtPath:logfile];
    if (fileHandle){
        [fileHandle seekToEndOfFile];
        [fileHandle writeData:[content dataUsingEncoding:NSUTF8StringEncoding]];
        [fileHandle closeFile];
    }
    else{
        [content writeToFile:logfile
                  atomically:NO
                    encoding:NSUTF8StringEncoding
                       error:nil];
    }
}

+(NSString*)GetLogs
{
    NSArray *arr = [[NSArray alloc] initWithArray: NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES)];
	NSString* documentsPath = [arr objectAtIndex: 0];
    NSString *logfile = [NSString stringWithFormat: ERRORLOGFILE, documentsPath];
    
    NSError *fileError = nil;
    
    NSString *fileContents = [[NSString stringWithContentsOfFile:logfile
                                              encoding:NSUTF8StringEncoding
                                                 error:&fileError] retain];
    return fileContents;
}

+(void)CleanLogFile
{
    //get the documents directory:
    NSArray *arr = [[NSArray alloc] initWithArray: NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES)];
	NSString* documentsPath = [arr objectAtIndex: 0];
    NSString *logfile = [NSString stringWithFormat: ERRORLOGFILE, documentsPath];
    
    NSFileHandle *fileHandle = [NSFileHandle fileHandleForWritingAtPath:logfile];
    if (fileHandle){
        [fileHandle truncateFileAtOffset:0];
        [fileHandle closeFile];
    }
}

@end
