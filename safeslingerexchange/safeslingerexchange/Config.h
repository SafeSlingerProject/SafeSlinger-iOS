/*
 * The MIT License (MIT)
 *
 * Copyright (c) 2010-2015 Carnegie Mellon University
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

#ifndef safeslingerexchange_Config_h
#define safeslingerexchange_Config_h

// For Key exchange part
#define MINICVERSION 0x01080000 // Client minimum version
#define MINICVERSIONSTR @"1.8.0" // Client minimum version
#define NONCELEN 32 // for keccak256
#define HASHLEN 32  // for keccak256
#define RETRYTIMEOUT 1
#define PROTOCOLTIMEOUT 600 // 10 mintues for users to finish the protocol
#define MAX_USERS 10
#define MIN_USERS 2
#define MAX_RETRY 15
#define DEFAULT_SERVER @"https://slinger-dev.appspot.com"

#endif
