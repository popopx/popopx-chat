//
//  hs_init.c
//  POPOPXChat
//
//  Created by Evgeny on 22/11/2023.
//  Copyright © 2023 SimpleX Chat. All rights reserved.
//

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
#include "hs_init.h"

extern void hs_init_with_rtsopts(int * argc, char **argv[]);

void haskell_init(void) {
    int argc = 5;
    char *argv[] = {
        "popopx",
        "+RTS", // requires `hs_init_with_rtsopts`
        "-A64m", // chunk size for new allocations
        "-H64m", // initial heap size
        "-xn", // non-moving GC
        0
    };
    char **pargv = argv;
    hs_init_with_rtsopts(&argc, &pargv);
}

void haskell_init_nse(void) {
    int argc = 7;
    char *argv[] = {
        "popopx",
        "+RTS", // requires `hs_init_with_rtsopts`
        "-A256k", // chunk size for new allocations
        "-H512k", // initial heap size
        "-F0.5", // heap growth triggering GC
        "-Fd0.3", // memory return
        "-c", // compacting garbage collector
        0
    };
    char **pargv = argv;
    hs_init_with_rtsopts(&argc, &pargv);
}

void haskell_init_se(void) {
    int argc = 7;
    char *argv[] = {
        "popopx",
        "+RTS", // requires `hs_init_with_rtsopts`
        "-A1m", // chunk size for new allocations
        "-H1m", // initial heap size
        "-F0.5", // heap growth triggering GC
        "-Fd1", // memory return
        "-c", // compacting garbage collector
        0
    };
    char **pargv = argv;
    hs_init_with_rtsopts(&argc, &pargv);
}
