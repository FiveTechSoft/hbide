// POSIX helpers for the mc demo (mc semantics verified in mc source):
//  - MC_FAllocate: posix_fallocate() contract of mc vfs_preallocate()
//    (lib/vfs/vfs.c:696): reserve physical space for the destination file.
//  - MC_CloneFile: whole-file COW clone via FICLONE ioctl, contract of
//    mc vfs_clone_file_by_path/vfs_clone_file() (lib/vfs/vfs.c:723+):
//    destination must not exist; caller falls back to a normal copy on error.

#include "hbapi.h"

#include <errno.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/ioctl.h>
#include <linux/fs.h>

// MC_FAllocate( nFD, nOffset, nLen ) -> 0 on success, errno otherwise
HB_FUNC( MC_FALLOCATE )
{
   int   nFD = hb_parni( 1 );
   off_t nOff = ( off_t ) hb_parnint( 2 );
   off_t nLen = ( off_t ) hb_parnint( 3 );

   hb_retni( nLen <= 0 ? 0 : posix_fallocate( nFD, nOff, nLen ) );
}

// MC_CloneFile( cSrc, cDst ) -> 0 on success (dst created as a COW clone),
// errno otherwise (EOPNOTSUPP on filesystems without reflink support).
// A failed attempt leaves no destination file behind.
HB_FUNC( MC_CLONEFILE )
{
   const char * szSrc = hb_parc( 1 );
   const char * szDst = hb_parc( 2 );
   int nSrc, nDst, nErr;

   if( szSrc == NULL || szDst == NULL )
   {
      hb_retni( EINVAL );
      return;
   }
   nSrc = open( szSrc, O_RDONLY );
   if( nSrc < 0 )
   {
      hb_retni( errno );
      return;
   }
   nDst = open( szDst, O_WRONLY | O_CREAT | O_EXCL, 0666 );
   if( nDst < 0 )
   {
      nErr = errno;
      close( nSrc );
      hb_retni( nErr );
      return;
   }
   nErr = ioctl( nDst, FICLONE, nSrc ) == 0 ? 0 : errno;
   close( nDst );
   close( nSrc );
   if( nErr != 0 )
      unlink( szDst );
   hb_retni( nErr );
}
