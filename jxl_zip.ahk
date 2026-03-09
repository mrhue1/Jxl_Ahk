; Convert jpg to jxl files in zip file
; jxl xxx
#Requires AutoHotkey v2.0
#DllLoad "minizip.dll"	; https://github.com/zlib-ng/minizip-ng/
#DllLoad "unrar64.dll"
#DllLoad "libdeflate.dll"

#DllLoad "jxl\"
#DllLoad "jxl.dll"
enc:=DllCall("jxl\JxlEncoderCreate","Ptr",0,"Ptr")
uz:=DllCall("minizip\mz_zip_reader_create","Ptr")
z:=DllCall("minizip\mz_zip_writer_create","Ptr")
DllCall("minizip\mz_zip_writer_set_raw","Ptr",z,"Int",1)
ld:=DllCall("libdeflate\libdeflate_alloc_compressor","Int",12,"Ptr")

src:=Buffer(4096*1024)			; source buffer
buf:=Buffer(4096*1024)			; jxl output buffer
out:=Buffer(4096*1024)			; libdeflate output buffer

utf:=Buffer(4096)				; utf filename buffer
fi:= Buffer(8+A_PtrSize*8+48+8,0)	; file info
NumPut("UInt",0x140a3f,fi)		; version
NumPut("Short",2 | 1<<11,fi,4)	; deflate max | utf
NumPut("Short",8,fi,6)			; compression method
NumPut("Ptr",utf.ptr,fi,8+A_PtrSize*4+48)	; filename

OnExit ExitFunc
SetWorkingDir A_InitialWorkingDir
if !A_Args.length {
	Loop Files, "*.zip" 
		if !InStr(A_LoopFileName, " jxl.zip") && !FileExist(SubStr(A_LoopFilename,1,-4) " jxl.zip")
			jxl(A_LoopFileName)	
	Loop Files, "*.rar" 
		if !InStr(A_LoopFileName, " jxl.zip") && !FileExist(SubStr(A_LoopFilename,1,-4) " jxl.zip")
			jxl(A_LoopFileName)	
	Loop Files, "*.*", "D"
		jxl(A_LoopFileName)
} else if A_Args[1]="x" {
	Loop A_Args.length-1
		Loop Files, A_Args[A_Index+1]
			jxx(A_LoopFilePath)
} else Loop A_Args.length
	jxl(A_Args[A_Index])
msgbox "done"
return

ExitFunc(ExitReason, ExitCode) {
	global z, uz
	DllCall("jxl\JxlEncoderDestroy","Ptr",enc)
	DllCall("minizip\mz_zip_reader_delete","Ptr*",&uz)
	DllCall("minizip\mz_zip_writer_delete","Ptr*",&z)
	DllCall("libdeflate\libdeflate_free_compressor","Ptr",ld)
	if IsSet(dec)
		DllCall("jxl\JxlDecoderDestroy","Ptr",dec)
}

rar_err(err) {
	static msg := ["Not enough memory", "Bad data (broken header/CRC error)", "Bad archive", "Unknown encryption", "Cannot open file", "Cannot create file", "Cannot close file", "Cannot read file", "Cannot write file", "Buffer too small", "Unknown error", "Missing password", "Reference error", "Invalid password"]
	if err>10
		MsgBox("Rar Err#" err ": " msg[err-10])
	return err
}

rar_open(fn, mode:=1) {	; OpenMode, 0=list, 1=test/extract, 2=read headers incl split archives
	static RAROpenArchiveDataEx := Buffer(A_PtrSize*5+132,0)
	; char         *ArcName;      ;0	0	Point to zero terminated Ansi archive name or NULL if Unicode name specified. 	
	; wchar_t      *ArcNameW;     ;4   8	Point to zero terminated Unicode archive name or NULL.
	; unsigned int  OpenMode;     ;8	16	RAR_OM_LIST = 0 (Read file headers); RAR_OM_EXTRACT = 1 (test/extract); RAR_OM_LIST_INCSPLIT = 2 (read file headers incl split archives)
	; unsigned int  OpenResult;   ;12	20	0 Success, ERAR_NO_MEMORY not enough memory, ERAR_BAD_DATA archive header broken, ERAR_UNKNOWN_FORMAT unknown encryption, EBAR_EOPEN open error, ERAR_BAD_PASSWORD invalid password (only for RAR5 archives)
	; char         *CmtBuf;       ;16	24	buffer for comments (max 64kb), if nul comment not read
	; unsigned int  CmtBufSize;   ;20	32	max size of comment buffer
	; unsigned int  CmtSize;      ;24  36	size of comment stored
	; unsigned int  CmtState;     ;28  40	0 No comments, 1 Comments read, ERAR_NO_MEMORY Not enough memory to extract comments, ERAR_BAD_DATA Broken comment, ERAR_SMALL_BUF Buffer is too small, comments are not read completely.
	; unsigned int  Flags;        ;32  44	1 archive volume, 2 comment present, 4 locked archive, 8 solid, 16 new naming scheme (volname.partN.rar), 32 authenticity info present (obsolete), 64 recovery record present, 128 headers encrypted, 256 first volume (RAR3.0 or later)
	; UNRARCALLBACK Callback;     ;36  48	callback address to process UnRAR events
	; LPARAM        UserData		;40  56	Userdefined data to pass to callback
	; unsigned int  Reserved[28]	;44  64	Reserved for future use, must be zero
							;152 172
	Numput("Ptr",StrPtr(fn),"UInt", mode, RAROpenArchiveDataEx, A_PtrSize)
	z:=DllCall("unrar64\RAROpenArchiveEx", "Ptr", RAROpenArchiveDataEx, "Ptr")
	rar_err(NumGet(RAROpenArchiveDataEx, A_PtrSize*2+4, "UInt"))
	return z
}

zip_open(fn,mode) {	; mode = r, w, a
	StrPut(fn,utf,"UTF-8")
	if mode="r" {
		if DllCall("minizip\mz_zip_reader_open_file","Ptr",uz,"Ptr",utf,"Int") 
			throw Error("Cannot open " fn " for reading")
		return uz
	} else if DllCall("minizip\mz_zip_writer_open_file","Ptr",z,"Ptr",utf,"Int64",0,"Int", mode="a" && FileExist(fn)!="","Int") 
		throw Error("Cannot open " fn " for writing")
	return z
}

zip_addbuf(src,sz) {
	global out
	if out.size < sz
		out := Buffer((sz + 4095) & ~4095)
	crc := DllCall("libdeflate\libdeflate_crc32","UInt",0,"Ptr",src,"Int64",sz,"UInt")
	NumPut("UInt",crc,fi,8+A_PtrSize*3)
	NumPut("Int64",sz,fi,8+A_PtrSize*4+8)
	if compsz := DllCall("libdeflate\libdeflate_deflate_compress","Ptr",ld,"Ptr",src,"Int",sz,"Ptr",out,"Int",sz) {
		NumPut("Short",8,fi,6)			; compression method deflate
		NumPut("Int64",compsz,fi,8+A_PtrSize*4)
		DllCall("minizip\mz_zip_writer_entry_open","Ptr",z,"Ptr",fi)
		DllCall("minizip\mz_zip_writer_entry_write","Ptr",z,"Ptr",out,"Int",compsz)
	} else {
		NumPut("Short",0,fi,6)			; compression method raw
		NumPut("Int64",sz,fi,8+A_PtrSize*4)
		DllCall("minizip\mz_zip_writer_entry_open","Ptr",z,"Ptr",fi)
		DllCall("minizip\mz_zip_writer_entry_write","Ptr",z,"Ptr",src,"Int",sz)
	}
	DllCall("minizip\mz_zip_writer_entry_close","Ptr",z)
}

zip_add(fn,time?) {
	global buf, src, enc, hModule
	static utc:=DateAdd(1970,DateDiff(A_Now,A_NowUTC,"s"),"s")
	if src.size < sz:=FileGetSize(fn)
		src := Buffer((sz + 4095) & ~4095)
	f:=FileOpen(fn,"r")
	f.pos:=0	; ahk automatically advances pointer by 3 if utf-8
	f.RawRead(src,sz)
	if !IsSet(time)
		time:=FileGetTime(fn)
    	NumPut("Int64",DateDiff(time,utc,"s"),fi,8)

	if RegExMatch(fn,"i)\.jpe?g$") {
     	DllCall("jxl\JxlEncoderReset","Ptr",enc)
		DllCall("jxl\JxlEncoderStoreJPEGMetadata","Ptr",enc,"Int",1)
		fs:=DllCall("jxl\JxlEncoderFrameSettingsCreate","Ptr",enc,"Ptr",0,"Ptr")
		if !DllCall("jxl\JxlEncoderAddJPEGFrame","Ptr",fs,"Ptr",src,"UInt",sz) {
			DllCall("jxl\JxlEncoderCloseInput","Ptr",enc)
			if buf.size < sz
				buf := buffer((sz + 4095) & ~4095)
			if !DllCall("jxl\JxlEncoderProcessOutput","Ptr",enc,"Ptr*",&b:=buf.ptr,"Int*",&avail:=sz) {
				StrPut(fn ".jxl",utf,"UTF-8")
				return zip_addbuf(buf,sz-avail)
				; return DllCall("minizip\mz_zip_writer_add_buffer","Ptr",z,"Ptr",buf,"UInt",sz-avail,"Ptr",fi)
			}
		}
	}
	StrPut(fn,utf,"UTF-8")
	return zip_addbuf(src,sz)
;	return DllCall("minizip\mz_zip_writer_add_file","Ptr",z,"Ptr",utf,"Ptr",utf)	; mz_zip_writer_add_file(zip_writer, path, filename_in_zip)
}

zip_copy(fn,unix_time?) {
	global buf, src
	if RegExMatch(fn,"i)\.jpe?g$") {
		sz := DllCall("minizip\mz_zip_reader_entry_save_buffer_length","Ptr",uz,"Int")
		if src.size < sz
			src:=buffer((sz + 4095) & ~4095)
		DllCall("minizip\mz_zip_reader_entry_save_buffer","Ptr",uz,"Ptr",src,"Int",sz)
     	DllCall("jxl\JxlEncoderReset","Ptr",enc)
		DllCall("jxl\JxlEncoderStoreJPEGMetadata","Ptr",enc,"Int",1)
		fs:=DllCall("jxl\JxlEncoderFrameSettingsCreate","Ptr",enc,"Ptr",0,"Ptr")
		if !DllCall("jxl\JxlEncoderAddJPEGFrame","Ptr",fs,"Ptr",src,"UInt",sz) {
			DllCall("jxl\JxlEncoderCloseInput","Ptr",enc)
			if buf.size < sz
				buf := buffer((sz + 4095) & ~4095)
			if !DllCall("jxl\JxlEncoderProcessOutput","Ptr",enc,"Ptr*",&b:=buf.ptr,"Int*",&avail:=sz) {
				if IsSet(unix_time)
		     		NumPut("Int64",unix_time,fi,8)
				StrPut(fn ".jxl",utf,"UTF-8")
				return DllCall("minizip\mz_zip_writer_add_buffer","Ptr",z,"Ptr",buf,"UInt",sz-avail,"Ptr",fi)
			}
	     }
	}
	return DllCall("minizip\mz_zip_writer_copy_from_reader","Ptr",z,"Ptr",uz)
}

zip_uncopy(fn,unix_time?) {
	global buf, src
	if RegExMatch(fn,"i)\.jxl$") {
		sz := DllCall("minizip\mz_zip_reader_entry_save_buffer_length","Ptr",uz,"Int")
		if src.size < sz
			src:=buffer((sz + 4095) & ~4095)
		DllCall("minizip\mz_zip_reader_entry_save_buffer","Ptr",uz,"Ptr",src,"Int",sz)

		if !IsSet(dec)
			global dec := DllCall("jxl\JxlDecoderCreate","Ptr",0,"Ptr")
		if buf.size < sz
			buf := buffer((sz + 4095) & ~4095)
		DllCall("jxl\JxlDecoderSetInput","Ptr",dec,"Ptr",src,"UInt",sz)
		DllCall("jxl\JxlDecoderCloseInput","Ptr",dec)
		DllCall("jxl\JxlDecoderSubscribeEvents","Ptr",dec,"UInt", 8192 | 4096)	; JXL_DEC_JPEG_RECONSTRUCTION | JXL_DEC_FULL_IMAGE
          r:=DllCall("jxl\JxlDecoderProcessInput","Ptr",dec)
          p:=buf.ptr, sz:=buf.size
          if r=8192 {	; ; JXL_DEC_JPEG_RECONSTRUCTION
	          Loop {
				DllCall("jxl\JxlDecoderSetJPEGBuffer","Ptr",dec,"Ptr",p,"Int",sz)
				r:=DllCall("jxl\JxlDecoderProcessInput","Ptr",dec)
				; JXL_DEC_SUCCESS = 0, JXL_DEC_ERROR = 1, JXL_DEC_NEED_MORE_OUTPUT = 2,
				; JXL_DEC_NEED_IMAGE_OUT_BUFFER = 5, JXL_DEC_JPEG_NEED_MORE_OUTPUT = 6,
          	     ; JXL_DEC_BASIC_INFO = 64
                    avail := DllCall("jxl\JxlDecoderReleaseJPEGBuffer","Ptr",dec)
                    if r=6 {
                    	sz := buf.size+avail
                    	buf.size += buf.size
                    	p := buf.ptr + buf.size - sz
                    } else break
               } 
          } 
          DllCall("jxl\JxlDecoderReset","Ptr",dec)
		if IsSet(unix_time)
     		NumPut("Int64",unix_time,fi,8)
     	if !RegExMatch(fn := RegExReplace(fn,"i)\.jxl$"), "\.jpe?g$")
     		fn .= ".jpg"
		StrPut(fn,utf,"UTF-8")
		return DllCall("minizip\mz_zip_writer_add_buffer","Ptr",z,"Ptr",buf,"UInt",buf.size-avail,"Ptr",fi)
	}
	return DllCall("minizip\mz_zip_writer_copy_from_reader","Ptr",z,"Ptr",uz)
}

jxx(fn) {
	static utc:=DateAdd(1970,DateDiff(A_Now,A_NowUTC,"s"),"s")
	global src, buf
	if FileExist(fn) {
		A_IconTip:=fn
		dir := RegExReplace(fn,".*\\|( jxl)?\.zip")
		zip_open(fn,"r")
		err:=DllCall("minizip\mz_zip_reader_goto_first_entry","Ptr",uz)
		while !err {
			if !DllCall("minizip\mz_zip_reader_entry_get_info","Ptr",uz,"Ptr*",&i:=0) {
				s := dir "\" StrReplace(StrGet(NumGet(i,8 + A_PtrSize *4 + 48,"Ptr"),"utf-8"),"/","\")	; filename, change / to \
				sz := DllCall("minizip\mz_zip_reader_entry_save_buffer_length","Ptr",uz,"Int")
				A_IconTip:=fn ": " s " " sz " bytes"
				if src.size < sz
					src:=buffer((sz + 4095) & ~4095)
				DllCall("minizip\mz_zip_reader_entry_save_buffer","Ptr",uz,"Ptr",src,"Int",sz)
				DirCreate(RegExReplace(s,"\\[^\\]+$"))
				if RegExMatch(s,"i)\.jxl$") {
					if !IsSet(dec)
						global dec := DllCall("jxl\JxlDecoderCreate","Ptr",0)
					if buf.size < sz
						buf := buffer((sz + 4095) & ~4095)
					DllCall("jxl\JxlDecoderSetInput","Ptr",dec,"Ptr",src,"UInt",sz)
					DllCall("jxl\JxlDecoderCloseInput","Ptr",dec)
					DllCall("jxl\JxlDecoderSubscribeEvents","Ptr",dec,"UInt", 8192 | 4096)	; JXL_DEC_JPEG_RECONSTRUCTION | JXL_DEC_FULL_IMAGE
			          r:=DllCall("jxl\JxlDecoderProcessInput","Ptr",dec)
			          p:=buf.ptr, sz:=buf.size
			          if r=8192 {	; ; JXL_DEC_JPEG_RECONSTRUCTION
				          Loop {
							DllCall("jxl\JxlDecoderSetJPEGBuffer","Ptr",dec,"Ptr",p,"Int",sz)
							r:=DllCall("jxl\JxlDecoderProcessInput","Ptr",dec)
							; JXL_DEC_SUCCESS = 0, JXL_DEC_ERROR = 1, JXL_DEC_NEED_MORE_OUTPUT = 2,
							; JXL_DEC_NEED_IMAGE_OUT_BUFFER = 5, JXL_DEC_JPEG_NEED_MORE_OUTPUT = 6,
			          	     ; JXL_DEC_BASIC_INFO = 64
               			     avail := DllCall("jxl\JxlDecoderReleaseJPEGBuffer","Ptr",dec)
			                    if r=6 {
			                    	sz := buf.size+avail
               			     	buf.size += buf.size
			                    	p := buf.ptr + buf.size - sz
			                    } else break
			               } 
			          } 
			          DllCall("jxl\JxlDecoderReset","Ptr",dec)
			     	if !RegExMatch(s := RegExReplace(s,"i)\.jxl$"), "\.jpe?g$")
			     		s .= ".jpg"
					f := FileOpen(s,"w")	; note the filename change here
			     	f.RawWrite(buf,buf.size-avail)
			     } else {
			     	f := FileOpen(s,"w")
			     	f.RawWrite(src,sz)
			     }
			     f.close()
			     FileSetTime(DateAdd(utc,NumGet(i,8,"Ptr"),"s"),s)
			}
			err:=DllCall("minizip\mz_zip_reader_goto_next_entry","Ptr",uz)
		}
	}
}

jxl(fn) {
	if FileExist(fn) {
		if InStr(FileGetAttrib(fn),"D") {	; jxl directory
			dir := A_WorkingDir
			totalsz := 0, totaln := 0
			Loop Files,fn,"D"
				zfn := A_LoopFileFullPath " jxl.zip", totalsz += A_LoopFileSize, totaln := A_Index 
			lst := "`n"
			if FileExist(zfn) {	; if dir jxl.zip already exists
				zip_open(zfn,"r")
				err:=DllCall("minizip\mz_zip_reader_goto_first_entry","Ptr",uz)
				while !err {
					if !DllCall("minizip\mz_zip_reader_entry_get_info","Ptr",uz,"Ptr*",&i:=0)
						lst .= StrGet(NumGet(i,8 + A_PtrSize *4 + 48,"Ptr"),"utf-8") "`n"
					err:=DllCall("minizip\mz_zip_reader_goto_next_entry","Ptr",uz)
				}
				lst := StrReplace(lst,"/","\")
			}
			SetWorkingDir(fn), n:=1, sz := 0

			Loop Files, "*.*", "R" {
				A_IconTip := fn "\" A_LoopFilename " (" A_Index " / " totaln " files; sz / " totalsz " bytes)"
				sz += A_LoopFileSize
				if InStr(lst,"`n" A_LoopFilePath "`n")	; don't compress if already exists in file
                    || InStr(lst,"`n" A_LoopFilePath ".jxl`n")
					continue
                    if !IsSet(z)
                    	z:=zip_open(zfn,"a")
                    zip_add(A_LoopFilePath,A_LoopFileTimeModified)
			}
			SetWorkingDir(dir)
		} else if InStr(fn," jxl.zip") {	; xxx jxl.zip
			if FileExist(zfn := SubStr(fn,1,-8) ".zip")
				return
			zip_open(fn,"r")
			err:=DllCall("minizip\mz_zip_reader_goto_first_entry","Ptr",uz)
			while !err {
				if !DllCall("minizip\mz_zip_reader_entry_get_info","Ptr",uz,"Ptr*",&i:=0) {
					s := StrReplace(StrGet(NumGet(i,8 + A_PtrSize *4 + 48,"Ptr"),"utf-8"),"/","\")	; filename, change / to \
					A_IconTip := fn ": " s " (" A_Index ") "
					if !IsSet(first)
						first:=zip_open(zfn,"w")
					zip_uncopy(s,NumGet(i,8,"Ptr"))
				}
				err:=DllCall("minizip\mz_zip_reader_goto_next_entry","Ptr",uz)
			}
		} else if InStr(fn,".zip") {	; xxx.zip
			if FileExist(zfn := SubStr(fn,1,-4) " jxl.zip")
				return
			zip_open(fn,"r")
			err:=DllCall("minizip\mz_zip_reader_goto_first_entry","Ptr",uz)
			while !err {
				if !DllCall("minizip\mz_zip_reader_entry_get_info","Ptr",uz,"Ptr*",&i:=0) {
					s := StrReplace(StrGet(NumGet(i,8 + A_PtrSize *4 + 48,"Ptr"),"utf-8"),"/","\")	; filename, change / to \
					A_IconTip := fn ": " s " (" A_Index ") "
					if !IsSet(first)
						first:=zip_open(zfn,"w")
					zip_copy(s,NumGet(i,8,"Ptr"))
				}
				err:=DllCall("minizip\mz_zip_reader_goto_next_entry","Ptr",uz)
			}
		} else if InStr(fn,".rar") {	; jxl xxx.rar
			if FileExist(zfn := SubStr(fn,1,-4) " jxl.zip")
				return
			rar := rar_open(fn)
			RARHeaderDataEx := Buffer(10224+A_PtrSize*3,0)
			while !HeaderResult := DllCall("unrar64\RARReadHeaderEx","Ptr",rar,"Ptr",RARHeaderDataEx)	{
				s := StrGet(RARHeaderDataEx.Ptr+4096 ,"utf-16")
				A_IconTip := fn ": " s " (" A_Index ") "
				dest := "R:\TEMP"
				if rar_err(DllCall("unrar64\RARProcessFileW","Ptr",rar,"Int",2,"Ptr",StrPtr(Dest),"Ptr",0))	; RAR_SKIP=0, RAR_TEST=1, RAR_EXTRACT=2
					continue
				if !IsSet(first)
					first:=zip_open(zfn,"w")
				zip_add(z,dest "\" s)
			}
			DllCall("unrar64\RARCloseArchive", "Ptr", uz)
		}
	} else {
		zfn := fn " jxl.zip"
		zip_open(zfn,"w")
		n:=1
		Loop Files, "*.*", "R" {	
			if A_LoopFilename = zfn
				continue
			A_IconTip := fn "\" A_LoopFilename " (" n++ ") "
			zip_add(A_LoopFilePath,A_LoopFileTimeModified)
		}
	}
}

;mz_zip_file file_info = { 0 };
;	file_info.filename = "newfile.txt";
;	file_info.modified_date = time(NULL);
;	file_info.version_madeby = MZ_VERSION_MADEBY;
;	file_info.compression_method = MZ_COMPRESS_METHOD_STORE;
;	file_info.flag = MZ_ZIP_FLAG_UTF8;
;
;2   uint16_t version_madeby;     /* version made by */
;	 MZ_HOST_SYSTEM_WINDOWS_NTFS    (10)
;	 MZ_VERSION_MADEBY_ZIP_VERSION (45)
;	 MZ_VERSION_MADEBY     ((MZ_VERSION_MADEBY_HOST_SYSTEM << 8) | (MZ_VERSION_MADEBY_ZIP_VERSION))
;2   uint16_t version_needed;     /* version needed to extract */
;2   uint16_t flag;               /* general purpose bit flag */	MZ_ZIP_FLAG_UTF8 | MZ_ZIP_FLAG_DEFLATE_MAX
;	MZ_ZIP_FLAG_ENCRYPTED          (1 << 0)
; 	MZ_ZIP_FLAG_LZMA_EOS_MARKER    (1 << 1)
; 	MZ_ZIP_FLAG_DEFLATE_MAX        (1 << 1)
; 	MZ_ZIP_FLAG_DEFLATE_NORMAL     (0)
; 	MZ_ZIP_FLAG_DEFLATE_FAST       (1 << 2)
; 	MZ_ZIP_FLAG_DEFLATE_SUPER_FAST (MZ_ZIP_FLAG_DEFLATE_FAST | MZ_ZIP_FLAG_DEFLATE_MAX)
; 	MZ_ZIP_FLAG_DATA_DESCRIPTOR    (1 << 3)
; 	MZ_ZIP_FLAG_UTF8               (1 << 11)
; 	MZ_ZIP_FLAG_MASK_LOCAL_INFO    (1 << 13)
;2   uint16_t compression_method; /* compression method */
;	 MZ_COMPRESS_METHOD_STORE   (0)
;	 MZ_COMPRESS_METHOD_DEFLATE (8)
;	 MZ_COMPRESS_METHOD_BZIP2   (12)
;	 MZ_COMPRESS_METHOD_LZMA    (14)
;	 MZ_COMPRESS_METHOD_ZSTD    (93)
;	 MZ_COMPRESS_METHOD_XZ      (95)
;	 MZ_COMPRESS_METHOD_AES     (99)
;a   time_t modified_date;        /* last modified date in unix time */
;a   time_t accessed_date;        /* last accessed date in unix time */
;a   time_t creation_date;        /* creation date in unix time */
;4   uint32_t crc;                /* crc-32 */
;
;8   int64_t compressed_size;     /* compressed size */
;8   int64_t uncompressed_size;   /* uncompressed size */	; NumGet(i,8 + A_PtrSize *4 + 8,"Int64")
;2   uint16_t filename_size;      /* filename length */	; NumGet(i,8 + A_PtrSize *4 + 16,"UShort")
;2   uint16_t extrafield_size;    /* extra field length */
;2   uint16_t comment_size;       /* file comment length */
;4   uint32_t disk_number;        /* disk number start */
;
;8   int64_t disk_offset;         /* relative offset of local header */
;2   uint16_t internal_fa;        /* internal file attributes */

;4   uint32_t external_fa;        /* external file attributes */
;a   const char *filename;        /* filename utf8 null-terminated string */	; StrGet(NumGet(i,8 + A_PtrSize *4 + 48,"Ptr"),"utf-8")
;a   const uint8_t *extrafield;   /* extrafield data */
;a   const char *comment;         /* comment utf8 null-terminated string */
;a   const char *linkname;        /* sym-link filename utf8 null-terminated string */
;2   uint16_t zip64;              /* zip64 extension mode */
;2   uint16_t aes_version;        /* winzip aes extension if not 0 */
;1   uint8_t aes_strength;        /* winzip aes encryption strength */
;2   uint16_t pk_verify;          /* pkware encryption verifier */
;
;struct RARHeaderDataEx
;{				  ;32 bit	64 bit
;  char         ArcName[1024];     ;0   		0
;  wchar_t      ArcNameW[1024];    ;1024		1024
;  char         FileName[1024];    ;3072		3072
;  wchar_t      FileNameW[1024];   ;4096		4096
;  unsigned int Flags;             ;6144		6144		; RHDF_SPLITBEFORE=1 Continued from previous volume, RHDF_SPLITAFTER=2 continued on next volume, RHDF_ENCRYPTED=4 encrypted, 8 reserved, 16 RHDF_SOLID, 32 RHDF_DIRECTORY
;  unsigned int PackSize;          ;6148         6148
;  unsigned int PackSizeHigh;      ;6152         6152
;  unsigned int UnpSize;           ;6156         6156
;  unsigned int UnpSizeHigh;       ;6160         6160
;  unsigned int HostOS;            ;6164         6164
;  unsigned int FileCRC;           ;6168         6168
;  unsigned int FileTime;          ;6172         6172
;  unsigned int UnpVer;            ;6176         6176
;  unsigned int Method;            ;6180         6180
;  unsigned int FileAttr;          ;6184         6184
;  char         *CmtBuf;           ;6188         6192
;  unsigned int CmtBufSize;        ;6192         6200
;  unsigned int CmtSize;           ;6196         6204
;  unsigned int CmtState;          ;6200         6208
;  unsigned int DictSize;          ;6204         6212
;  unsigned int HashType;          ;6208         6216
;  char         Hash[32];          ;6212         6220
;  unsigned int RedirType;	  ;6244		6252
;  wchar_t      *RedirName;	  ;6248		6256
;  unsigned int RedirNameSize;     ;6252		6264
;  unsigned int DirTarget;         ;6256         6268
;  unsigned int MtimeLow;          ;6260         6272
;  unsigned int MtimeHigh;         ;6264         6276
;  unsigned int CtimeLow;          ;6268         6280
;  unsigned int CtimeHigh;         ;6272         6284
;  unsigned int AtimeLow;          ;6276         6288
;  unsigned int AtimeHigh;         ;6280         6292
;  unsigned int Reserved[988]      ;6284         6296
;};                                ;10236	10248
