// -*- mode: ObjC -*-

//  This file is part of class-dump, a utility for examining the Objective-C segment of Mach-O files.
//  Copyright (C) 1997-1998, 2000-2001, 2004-2009 Steve Nygard.

#import "CDLCDynamicSymbolTable.h"

#include <mach-o/loader.h>
#include <mach-o/swap.h>
#import "CDFatFile.h"
#import "CDMachOFile.h"
#import "CDDataCursor.h"

@implementation CDLCDynamicSymbolTable

- (id)initWithDataCursor:(CDDataCursor *)cursor machOFile:(CDMachOFile *)aMachOFile;
{
    if ([super initWithDataCursor:cursor machOFile:aMachOFile] == nil)
        return nil;

    dysymtab.cmd = [cursor readInt32];
    dysymtab.cmdsize = [cursor readInt32];

    dysymtab.ilocalsym = [cursor readInt32];
    dysymtab.nlocalsym = [cursor readInt32];
    dysymtab.iextdefsym = [cursor readInt32];
    dysymtab.nextdefsym = [cursor readInt32];
    dysymtab.iundefsym = [cursor readInt32];
    dysymtab.nundefsym = [cursor readInt32];
    dysymtab.tocoff = [cursor readInt32];
    dysymtab.ntoc = [cursor readInt32];
    dysymtab.modtaboff = [cursor readInt32];
    dysymtab.nmodtab = [cursor readInt32];
    dysymtab.extrefsymoff = [cursor readInt32];
    dysymtab.nextrefsyms = [cursor readInt32];
    dysymtab.indirectsymoff = [cursor readInt32];
    dysymtab.nindirectsyms = [cursor readInt32];
    dysymtab.extreloff = [cursor readInt32];
    dysymtab.nextrel = [cursor readInt32];
    dysymtab.locreloff = [cursor readInt32];
    dysymtab.nlocrel = [cursor readInt32];
#if 1
    NSLog(@"ilocalsym:      0x%08x  %d", dysymtab.ilocalsym, dysymtab.ilocalsym);
    NSLog(@"nlocalsym:      0x%08x  %d", dysymtab.nlocalsym, dysymtab.nlocalsym);
    NSLog(@"iextdefsym:     0x%08x  %d", dysymtab.iextdefsym, dysymtab.iextdefsym);
    NSLog(@"nextdefsym:     0x%08x  %d", dysymtab.nextdefsym, dysymtab.nextdefsym);
    NSLog(@"iundefsym:      0x%08x  %d", dysymtab.iundefsym, dysymtab.iundefsym);
    NSLog(@"nundefsym:      0x%08x  %d", dysymtab.nundefsym, dysymtab.nundefsym);

    NSLog(@"tocoff:         0x%08x  %d", dysymtab.tocoff, dysymtab.tocoff);
    NSLog(@"ntoc:           0x%08x  %d", dysymtab.ntoc, dysymtab.ntoc);
    NSLog(@"modtaboff:      0x%08x  %d", dysymtab.modtaboff, dysymtab.modtaboff);
    NSLog(@"nmodtab:        0x%08x  %d", dysymtab.nmodtab, dysymtab.nmodtab);

    NSLog(@"extrefsymoff:   0x%08x  %d", dysymtab.extrefsymoff, dysymtab.extrefsymoff);
    NSLog(@"nextrefsyms:    0x%08x  %d", dysymtab.nextrefsyms, dysymtab.nextrefsyms);
    NSLog(@"indirectsymoff: 0x%08x  %d", dysymtab.indirectsymoff, dysymtab.indirectsymoff);
    NSLog(@"nindirectsyms:  0x%08x  %d", dysymtab.nindirectsyms, dysymtab.nindirectsyms);

    NSLog(@"extreloff:      0x%08x  %d", dysymtab.extreloff, dysymtab.extreloff);
    NSLog(@"nextrel:        0x%08x  %d", dysymtab.nextrel, dysymtab.nextrel);
    NSLog(@"locreloff:      0x%08x  %d", dysymtab.locreloff, dysymtab.locreloff);
    NSLog(@"nlocrel:        0x%08x  %d", dysymtab.nlocrel, dysymtab.nlocrel);
#endif
    return self;
}

- (uint32_t)cmd;
{
    return dysymtab.cmd;
}

- (uint32_t)cmdsize;
{
    return dysymtab.cmdsize;
}

- (void)loadSymbols;
{
    CDDataCursor *cursor;
    uint32_t index;

    NSLog(@" > %s", _cmd);

    cursor = [[CDDataCursor alloc] initWithData:[nonretainedMachOFile data]];
    [cursor setByteOrder:[nonretainedMachOFile byteOrder]];
    [cursor setOffset:dysymtab.indirectsymoff]; // TODO: + file offset for fat files?

    NSLog(@"indirectsymoff: %lu", dysymtab.indirectsymoff);
    NSLog(@"nindirectsyms:  %lu", dysymtab.nindirectsyms);

    for (index = 0; index < dysymtab.nindirectsyms; index++) {
        uint32_t val;

        // From loader.h: An indirect symbol table entry is simply a 32bit index into the symbol table to the symbol that the pointer or stub is referring to.
        val = [cursor readInt32];
        NSLog(@"%3u: %08x (%u)", index, val, val);
    }

    NSLog(@"extreloff: %lu", dysymtab.extreloff);
    NSLog(@"nextrel:   %lu", dysymtab.nextrel);

    [cursor setOffset:dysymtab.extreloff];
    NSLog(@"     address   val       symbolnum  pcrel  len  ext  type");
    NSLog(@"---  --------  --------  ---------  -----  ---  ---  ----");
    for (index = 0; index < dysymtab.nextrel; index++) {
        struct relocation_info rinfo;
        uint32_t val;

        rinfo.r_address = [cursor readInt32];
        val = [cursor readInt32];
        rinfo.r_symbolnum = val & 0x00ffffff;
        rinfo.r_pcrel = (val & 0x01000000) >> 24;
        rinfo.r_length = (val & 0x06000000) >> 25;
        rinfo.r_extern = (val & 0x08000000) >> 27;
        rinfo.r_type = (val & 0xf0000000) >> 28;
        NSLog(@"%3d: %08x  %08x   %08x      %01x    %01x    %01x     %01x", index, rinfo.r_address, val,
              rinfo.r_symbolnum, rinfo.r_pcrel, rinfo.r_length, rinfo.r_extern, rinfo.r_type);
    }

    // r_address is purported to be the offset from the vmaddr of the first segment, but...
    // it appears to be the offset from the vmaddr of the 3rd segment in t1s.
    // Actually, it really seems to be the offset from the vmaddr of the section indicated in the n_desc part of the nlist.
    // So for t1s and NSObject... 0000000100001028...
    // 0000000000000000 01 00 0500 0000000000000038 _OBJC_CLASS_$_NSObject
    // The "05" seems to indicate the section ordinal (starting at zero)
    // Also seem to have to worry about two level namespaces
    // GET_LIBRARY_ORDINAL() from nlist.h -- no, not library for this.
    // Maybe first "read/write" command (initprot)?... but MH_SPLIT_SEGS?

    [cursor release];

    NSLog(@"<  %s", _cmd);
}

@end
