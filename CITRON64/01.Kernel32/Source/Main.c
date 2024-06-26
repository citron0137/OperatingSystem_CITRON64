#include "Types.h"
#include "Page.h"
#include "ModeSwitch.h"

void kPrintString( int iX, int iY, const char* pcString );
void kPrintStringWithCheckBox( int iY, const char* pcString );
void kFillCheckBox( int iY, const char* pcString );
BOOL kInitializeKernel64Area( void );
BOOL kIsMemoryEnough( void );
void kCopyKernel64ImageTo2Mbyte( void );

void Main( void ){
    DWORD i;

    kPrintStringWithCheckBox( 3, "Start Protected Mode C Kernel" );
    kFillCheckBox( 3, "Pass" );
    
    kPrintStringWithCheckBox( 4, "Check minimum memory size" );
    if(kIsMemoryEnough() == FALSE){
        kFillCheckBox( 4, "Fail" );
        kPrintString( 0, 5, "NotEnoughMemory ( > 64Mb )" );
        while( 1 );
    }
    else{
        kFillCheckBox( 4, "Pass" );
    }

    kPrintStringWithCheckBox( 5, "Initialize IA-32e Kernel Area" );
    if(kInitializeKernel64Area() == FALSE){
        kFillCheckBox( 5, "Fail" );
        kPrintString( 0, 6, "Failed to initialize IA-32e Kernel Area" );
        while( 1 );
    }
    else{
        kFillCheckBox( 5, "Pass" );
    }
    
    kPrintStringWithCheckBox( 6, "Initialize IA-32e Page Tables" );
    kInitializePageTables();
    kFillCheckBox( 6, "Pass" );
    
    // Read Processor Vendor
    kPrintStringWithCheckBox( 7, "Read Processor Vendor" );
    DWORD dwEAX, dwEBX, dwECX, dwEDX;
    char vcVendorString[ 13 ] = { 0, };
    kReadCPUID(0x00, &dwEAX, &dwEBX, &dwECX, &dwEDX);
    *( DWORD* ) vcVendorString = dwEBX;
    *( ( DWORD* ) vcVendorString + 1) = dwEDX;
    *( ( DWORD* ) vcVendorString + 2) = dwECX;
    kFillCheckBox( 7, vcVendorString );
    
    // Check 64bit support
    kPrintStringWithCheckBox( 8, "Check 64bit Support" );
    kReadCPUID(0x80000001, &dwEAX, &dwEBX, &dwECX, &dwEDX);
    if( dwEDX & ( 1 << 29) )
        kFillCheckBox( 8, "Pass" );
    else{
        kFillCheckBox( 8, "Fail" );
        kPrintString( 0, 9, "Processor does not support 64bit" );
        while( 1 );
    }

    kPrintStringWithCheckBox( 9, "Copy IA-32e Kernel to 2M(Addr)" );
    kCopyKernel64ImageTo2Mbyte();
    kFillCheckBox( 9, "Pass" );
    kPrintStringWithCheckBox( 10, "Switch To IA-32e Mode" );
    kSwitchAndExecute64bitKernel();

    while(1);
}

void kPrintString( int iX, int iY, const char* pcString ){
    CHARACTER* pstScreen = ( CHARACTER* ) 0xB8000; 
    pstScreen += ( iY * 80 ) + iX;
    for( int i = 0; pcString[i] != 0; i++ )
    {
        pstScreen[ i ].bCharactor = pcString[ i ];
    }
}
void kPrintStringWithCheckBox( int iY, const char* pcString ){
    kPrintString( 0, iY, "............................................[    ]"); 
    kPrintString( 0, iY, pcString );
}

void kFillCheckBox( int iY, const char* pcString ){
    kPrintString( 45, iY, pcString );
}

BOOL kInitializeKernel64Area( void ){
    DWORD* pdwCurrentAddress;
    pdwCurrentAddress = ( DWORD* ) 0x100000;
    while( pdwCurrentAddress <= ( DWORD* ) 0x600000 ){
        *pdwCurrentAddress = 0x00;
        if( *pdwCurrentAddress != 0 ) return FALSE;
        pdwCurrentAddress++;
    }
    return TRUE;
}

BOOL kIsMemoryEnough( void ){
    DWORD* pdwCurrentAddress = ( DWORD* ) 0x100000;
    while( pdwCurrentAddress <= ( DWORD* ) 0x400000 ){
        *pdwCurrentAddress = 0x12345678;
        if( *pdwCurrentAddress != 0x12345678 ) return FALSE;
        pdwCurrentAddress += ( 0x100000 / 4 );
    }
    return TRUE;
}

void kCopyKernel64ImageTo2Mbyte( void ){
    WORD wKernel32SectorCount, wTotalKernelSectorCount;
    wTotalKernelSectorCount = *( (WORD*) 0x7c05 );
    wKernel32SectorCount = *( (WORD*) 0x7c07 );
    
    DWORD* pdwSrcAddress, * pdwDstAddress;
    pdwSrcAddress = (DWORD*) ( 0x10000 + (wKernel32SectorCount * 512));
    pdwDstAddress = (DWORD*) 0x200000;

    for( int i = 0; i < 512 * ( wTotalKernelSectorCount - wKernel32SectorCount ) / 4; i++){
        *pdwDstAddress = *pdwSrcAddress;
        pdwDstAddress++;
        pdwSrcAddress++;
    }
}