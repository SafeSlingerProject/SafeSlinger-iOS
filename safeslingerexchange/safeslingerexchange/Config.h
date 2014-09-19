//
//  Config.h
//  safeslingerexchange
//
//  Created by Yueh-Hsun Lin on 5/22/14.
//  Copyright (c) 2014 CyLab. All rights reserved.
//

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
