; [url=https://jpegxl.info/]JPEG XL[/url] (abbreviated .jxl) is a modern, open-source, and royalty-free image file format designed for superior lossy and lossless compression compared to JPEG and PNG. Libjxl source and DLL files are available at [url=https://github.com/libjxl/libjxl]github[/url]

#Requires AutoHotkey v2.0
#DllLoad "jxl.dll"
jxl("test.webp")
cjxl("jxl_basic.ahk")
cjxl("00.jpeg")
djxl("00.jpeg.jxl")
showjxl("00.jpeg.jxl")

cjxl(fn) {	; transcode jpeg to jxl
	if j:=DllCall("jxl\JxlEncoderCreate","Ptr",0,"Ptr") {
		DllCall("jxl\JxlEncoderStoreJPEGMetadata","Ptr",j,"Int",1)
		b:=FileRead(fn,"RAW")
		fs:=DllCall("jxl\JxlEncoderFrameSettingsCreate","Ptr",j,"Ptr",0,"Ptr")
		if !DllCall("jxl\JxlEncoderAddJPEGFrame","Ptr",fs,"Ptr",b.ptr,"UInt",b.size) {	; valid jpeg
			DllCall("jxl\JxlEncoderCloseInput","Ptr",j)
			o:=Buffer(b.size)
			Loop {
				r:=DllCall("jxl\JxlEncoderProcessOutput","Ptr",j,"Ptr*",&buf:=o.ptr,"Int*",&bytes:=o.size)
				; JXL_ENC_SUCCESS = 0, JXL_ENC_ERROR = 1, JXL_ENC_NEED_MORE_OUTPUT = 2,
				if r=1 {
					MsgBox("Encoder failed for " fn)
					break
				} else if !IsSet(f)
					f:=FileOpen(fn ".jxl","w")
				f.RawWrite(o,o.size-bytes)
			} until !r
			if IsSet(f)
				f.Close()
		} else MsgBox("Invalide jpeg file: " fn)
		DllCall("jxl\JxlEncoderDestroy","Ptr",j)
	}
}

jxl(fn,quality:=50,compression:=9) {	; lossy image to jxl without alpha, compression is 1 to 9
	static IWICImagingFactory := ComObject(WICImagingFactory := "{CACAF262-9370-4615-A13B-9F5539DA4C0A}", IWICImagingFactory:="{EC5EC8A9-C395-4314-9C77-54D7A935FF70}")
		, WICPixelFormat32bppBGRA:=(Numput("Int64",0x4BFE4E036FDDC324,"Int64",0x0FC98D76773D85B1,b:=buffer(16)),b)	; {6fddc324-4e03-4bfe-b185-3d77768dc90f}
		, WICPixelFormat32bppRGBA:=(Numput("Int64",0x43DD6A8DF5C7AD2D,"Int64",0xE91A263599A2A8A7,b:=buffer(16)),b)	; {f5c7ad2d-6a8d-43dd-a7a8-a29935261ae9}
		, WICPixelFormat24bppRGB:=(Numput("Int64", 0x4BFE4E036FDDC324,"Int64",0x0DC98D76773D85B1,b:=buffer(16)),b)	; {6fddc324-4e03-4bfe-b185-3d77768dc90d}
		, GENERIC_READ := 0x80000000, decodeOption := WICDecodeMetadataCacheOnDemand := 0
		, dither := WICBitmapDitherTypeNone := 0, paletteType := WICBitmapPaletteTypeCustom := 0

	if enc:=DllCall("jxl\JxlEncoderCreate","Ptr",0,"Ptr") {
		ComCall(CreateDecoderFromFilename:=3,IWICImagingFactory,"Str", fn,"Ptr",0,"UInt",GENERIC_READ,"Int",decodeOption,"PtrP",&IWICBitmapDecoder:=0)
		ComCall(GetFrame := 13,IWICBitmapDecoder,"UInt", 0, "PtrP", &IWICBitmapFrameDecode:=0)
		ComCall(CreateFormatConverter:=10,IWICImagingFactory,"PtrP", &IWICFormatConverter:=0)
		ComCall(Initialize := 8,IWICFormatConverter,"Ptr", IWICBitmapFrameDecode, "Ptr", WICPixelFormat24bppRGB, "Int", dither, "Ptr", 0, "Double", 0, "Int", paletteType )
		ComCall(GetSize    := 3,IWICFormatConverter,"UIntP", &width:=0, "UIntP", &height:=0)
		; stride := width * 4	; if using 32bpp
		stride := (width * 3 + 3) & ~3	; stride (width * 3 bytes, padded to 4 bytes) for 24 bpp
		ComCall(CopyPixels := 7,IWICFormatConverter,"Ptr", 0, "UInt", stride, "UInt", stride * height, "Ptr", pBits:=Buffer(stride * height))

		DllCall("jxl\JxlEncoderInitBasicInfo","Ptr",info:=Buffer(204))
		NumPut("UInt",width,"UInt",height,info,4)
		; NumPut("UInt",width,"UInt",height,"UInt",8,info,4)
		; NumPut("UInt",1,"UInt",8,"UInt",0,info,4*14)	; alpha
		; MsgBox NumGet(info,12*4,"UInt")

		if IsSet(debug) {
			vars:=["have_container","xsize","ysize","bits_per_sample","exponent_bits_per_sample","intensity_target","min_nits",
				"relative_to_max_display","linear_below","uses_original_profile","have_preview","have_animation","orientation","num_color_channels",
				"num_extra_channels","alpha_bits","alpha_exponent_bits","alpha_premultiplied","preview.xsize","preview.ysize",
				"animation.tps_numerator","animation.tps_denominator","animation.num_loops","animation.have_timecodes","intrinsic_xsize","intrinsic_ysize"]
			for v in vars {
				lst .= v ": " NumGet(info,A_Index*4-4,"UInt") "`n"
			}
;JXL_BOOL have_container„r;Whether the codestream is embedded in the container format. If true, metadata information and extensions may be available in addition to the codestream.
;uint32_t xsize„r;Width of the image in pixels, before applying orientation.
;uint32_t ysize  ;Height of the image in pixels, before applying orientation.
;uint32_t bits_per_sample„r;Original image color channel bit depth.
;uint32_t exponent_bits_per_sample„r;Original image color channel floating point exponent bits, or 0 if they are unsigned integer. For example, if the original data is half-precision (binary16) floating point, bits_per_sample is 16 and exponent_bits_per_sample is 5, and so on for other floating point precisions.
;float intensity_target„r;Upper bound on the intensity level present in the image in nits. For unsigned integer pixel encodings, this is the brightness of the largest representable value. The image does not necessarily contain a pixel actually this bright. An encoder is allowed to set 255 for SDR images without computing a histogram. Leaving this set to its default of 0 lets libjxl choose a sensible default value based on the color encoding.
;float min_nits„r;Lower bound on the intensity level present in the image. This may be loose, i.e. lower than the actual darkest pixel. When tone mapping, a decoder will map [min_nits, intensity_target] to the display range.
;JXL_BOOL relative_to_max_display„r;The tone mapping will leave unchanged (linear mapping) any pixels whose brightness is strictly below this. The interpretation depends on relative_to_max_display. If true, this is a ratio [0, 1] of the maximum display brightness [nits], otherwise an absolute brightness [nits].
; float linear_below„r; The tone mapping will leave unchanged (linear mapping) any pixels whose brightness is strictly below this. The interpretation depends on relative_to_max_display. If true, this is a ratio [0, 1] of the maximum display brightness [nits], otherwise an absolute brightness [nits].
;JXL_BOOL uses_original_profile„r;Whether the data in the codestream is encoded in the original color profile that is attached to the codestream metadata header, or is encoded in an internally supported absolute color space (which the decoder can always convert to linear or non-linear sRGB or to XYB). If the original profile is used, the decoder outputs pixel data in the color space matching that profile, but doesn¡¦t convert it to any other color space. If the original profile is not used, the decoder only outputs the data as sRGB (linear if outputting to floating point, nonlinear with standard sRGB transfer function if outputting to unsigned integers) but will not convert it to to the original color profile. The decoder also does not convert to the target display color profile. To convert the pixel data produced by the decoder to the original color profile, one of the JxlDecoderGetColor* functions needs to be called with JXL_COLOR_PROFILE_TARGET_DATA to get the color profile of the decoder output, and then an external CMS can be used for conversion. Note that for lossy compression, this should be set to false for most use cases, and if needed, the image should be converted to the original color profile after decoding, as described above.
;JXL_BOOL have_preview„r;Indicates a preview image exists near the beginning of the codestream. The preview itself or its dimensions are not included in the basic info.
;JXL_BOOL have_animation„r;Indicates animation frames exist in the codestream. The animation information is not included in the basic info.
;JxlOrientation orientation„r;Image orientation, value 1-8 matching the values used by JEITA CP-3451C (Exif version 2.3).
;uint32_t num_color_channels„r;Number of color channels encoded in the image, this is either 1 for grayscale data, or 3 for colored data. This count does not include the alpha channel or other extra channels. To check presence of an alpha channel, such as in the case of RGBA color, check alpha_bits != 0. If and only if this is 1, the JxlColorSpace in the JxlColorEncoding is JXL_COLOR_SPACE_GRAY.
;uint32_t num_extra_channels„r;Number of additional image channels. This includes the main alpha channel, but can also include additional channels such as depth, additional alpha channels, spot colors, and so on. Information about the extra channels can be queried with JxlDecoderGetExtraChannelInfo. The main alpha channel, if it exists, also has its information available in the alpha_bits, alpha_exponent_bits and alpha_premultiplied fields in this JxlBasicInfo.
;uint32_t alpha_bits„r;Bit depth of the encoded alpha channel, or 0 if there is no alpha channel. If present, matches the alpha_bits value of the JxlExtraChannelInfo associated with this alpha channel.
;uint32_t alpha_exponent_bits„r;Alpha channel floating point exponent bits, or 0 if they are unsigned. If present, matches the alpha_bits value of the JxlExtraChannelInfo associated with this alpha channel. integer.
;JXL_BOOL alpha_premultiplied„r;Whether the alpha channel is premultiplied. Only used if there is a main alpha channel. Matches the alpha_premultiplied value of the JxlExtraChannelInfo associated with this alpha channel.
;JxlPreviewHeader preview„r;Dimensions of encoded preview image, only used if have_preview is JXL_TRUE.
;JxlAnimationHeader animation„r;Animation header with global animation properties for all frames, only used if have_animation is JXL_TRUE.
;uint32_t intrinsic_xsize„r;Intrinsic width of the image. The intrinsic size can be different from the actual size in pixels (as given by xsize and ysize) and it denotes the recommended dimensions for displaying the image, i.e. applications are advised to resample the decoded image to the intrinsic dimensions.
;uint32_t intrinsic_ysize„r;Intrinsic height of the image. The intrinsic size can be different from the actual size in pixels (as given by xsize and ysize) and it denotes the recommended dimensions for displaying the image, i.e. applications are advised to resample the decoded image to the intrinsic dimensions.
			MsgBox lst
		}

		if DllCall("jxl\JxlEncoderSetBasicInfo","Ptr",enc,"Ptr",info) 
			Throw "JxlEncoderSetBasicInfo failed"

		DllCall("jxl\JxlColorEncodingSetToSRGB","Ptr",color_encoding:=Buffer(100,0),"UInt",isgray:=0)
;4 JxlColorSpace color_space„rColor space of the image data. enum JXL_COLOR_SPACE_RGB, JXL_COLOR_SPACE_GRAY, JXL_COLOR_SPACE_XYB, JXL_COLOR_SPACE_UNKNOWN
;4 JxlWhitePoint white_point„rBuilt-in white point. If this value is JXL_WHITE_POINT_CUSTOM, must use the numerical white point values from white_point_xy.  Enum D65, CUSTOM, E, DCI
;16 double white_point_xy[2]„rNumerical whitepoint values in CIE xy space. Double=8 bytes
;4 JxlPrimaries primaries„rBuilt-in RGB primaries. If this value is JXL_PRIMARIES_CUSTOM, must use the numerical primaries values below. This field and the custom values below are unused and must be ignored if the color space is JXL_COLOR_SPACE_GRAY or JXL_COLOR_SPACE_XYB.
;16 double primaries_red_xy[2]„rNumerical red primary values in CIE xy space.
;16 double primaries_green_xy[2]„rNumerical green primary values in CIE xy space.
;16 double primaries_blue_xy[2]„rNumerical blue primary values in CIE xy space.
;4 JxlTransferFunction transfer_function„rTransfer function if have_gamma is 0
;8 double gamma„rGamma value used when transfer_function is JXL_TRANSFER_FUNCTION_GAMMA
;4 JxlRenderingIntent rendering_intent„r

		if DllCall("jxl\JxlEncoderSetColorEncoding","Ptr",enc,"Ptr",color_encoding)
			MsgBox "JxlEncoderSetColorEncodingfailed"

		fs:=DllCall("jxl\JxlEncoderFrameSettingsCreate","Ptr",enc,"Ptr",0,"Ptr")

		if (quality >= 100) {	; default is 90
			; DllCall("jxl\JxlEncoderSetFrameDistance","Ptr",fs,"float",0)	
			DllCall("jxl\JxlEncoderSetFrameLossless","Ptr",fs,"UInt",1)
		} else DllCall("jxl\JxlEncoderSetFrameDistance","Ptr",fs,"float",DllCall("jxl\JxlEncoderDistanceFromQuality","float",quality,"float"))	

          DllCall("jxl\JxlEncoderFrameSettingsSetOption","Ptr",fs,"UInt",0,"UInt",compression)	; default is 7
          		
		NumPut("UInt",3,"UInt",2,pixel_format:=Buffer(8+A_PtrSize*2,0))
		; pixel_format := {3, JXL_TYPE_UINT8, JXL_NATIVE_ENDIAN, 0};
		; uint32_t num_channels: Amount of channels available in a pixel buffer. 1: single-channel data, e.g. grayscale or a single extra channel 2: single-channel + alpha 3: trichromatic, e.g. RGB 4: trichromatic + alpha TODO(lode): this needs finetuning. It is not yet defined how the user chooses output color space. CMYK+alpha needs 5 channels.
		; enum JxlDataType„rData type for the sample values per channel per pixel.
		;	0 JXL_TYPE_FLOAT„rUse 32-bit single-precision floating point values, with range 0.0-1.0 (within gamut, may go outside this range for wide color gamut). Floating point output, either JXL_TYPE_FLOAT or JXL_TYPE_FLOAT16, is recommended for HDR and wide gamut images when color profile conversion is required.
		;	2 JXL_TYPE_UINT8„rUse type uint8_t. May clip wide color gamut data.
		;	3 JXL_TYPE_UINT16„rUse type uint16_t. May clip wide color gamut data.
		; 	5 JXL_TYPE_FLOAT16 Use 16-bit IEEE 754 half-precision floating point values
		; enum JxlEndianness„rOrdering of multi-byte data. This applies to JXL_TYPE_UINT16 and JXL_TYPE_FLOAT.
		;	0 JXL_NATIVE_ENDIAN„rUse the endianness of the system, either little endian or big endian, without forcing either specific endianness. Do not use if pixel data should be exported to a well defined format.
		;	1 JXL_LITTLE_ENDIAN„rForce little endian
		;	2 JXL_BIG_ENDIAN„rForce big endian
		; size_t align„r
		; JXL_EXPORT JxlEncoderStatus JxlEncoderAddImageFrame(const JxlEncoderFrameSettings *frame_settings, const JxlPixelFormat *pixel_format, const void *buffer, size_t size)
		if !DllCall("jxl\JxlEncoderAddImageFrame","Ptr",fs,"Ptr",pixel_format,"Ptr",pBits.ptr,"Ptr",pBits.size) {	; pixel data
			A_IconTip := "Encoding " pBits.size " bytes... "
			DllCall("jxl\JxlEncoderCloseInput","Ptr",enc)
			o:=Buffer(b.size)
			Loop {
				A_IconTip := "Encoding " pBits.size " bytes... " A_Index
				r:=DllCall("jxl\JxlEncoderProcessOutput","Ptr",enc,"Ptr*",&buf:=o.ptr,"Int*",&bytes:=o.size)
				; JXL_ENC_SUCCESS = 0, JXL_ENC_ERROR = 1, JXL_ENC_NEED_MORE_OUTPUT = 2,
				if r=1 {
					MsgBox("Encoder failed for " fn)
					break
				} else if !IsSet(f)
					f:=FileOpen(fn ".jxl","w")
				f.RawWrite(o,o.size-bytes)
			} until !r
			if IsSet(f)
				f.Close()
		} else MsgBox("JxlEncoderAddImageFrame failed for: " fn)
		DllCall("jxl\JxlEncoderDestroy","Ptr",enc)
	}
}


djxl(fn) {	; decodes jxl to jpg
	if j:=DllCall("jxl\JxlDecoderCreate","Ptr",0,"Ptr") {
		b:=FileRead(fn,"RAW")
		DllCall("jxl\JxlDecoderSetInput","Ptr",j,"Ptr",b.ptr,"UInt",b.size)
		DllCall("jxl\JxlDecoderCloseInput","Ptr",j)
		DllCall("jxl\JxlDecoderSubscribeEvents","Ptr",j,"UInt", 8192 | 4096)	; JXL_DEC_JPEG_RECONSTRUCTION | JXL_DEC_FULL_IMAGE
          r:=DllCall("jxl\JxlDecoderProcessInput","Ptr",j)
          if r=8192 {	; ; JXL_DEC_JPEG_RECONSTRUCTION
	          Loop {
				o:=Buffer(b.size*2)
				DllCall("jxl\JxlDecoderSetJPEGBuffer","Ptr",j,"Ptr",o,"Int",o.size)
				r:=DllCall("jxl\JxlDecoderProcessInput","Ptr",j)
				; JXL_DEC_SUCCESS = 0, JXL_DEC_ERROR = 1, JXL_DEC_NEED_MORE_OUTPUT = 2,
				; JXL_DEC_NEED_IMAGE_OUT_BUFFER = 5, JXL_DEC_JPEG_NEED_MORE_OUTPUT = 6,
          	     ; JXL_DEC_BASIC_INFO = 64
				if r=1 {
					MsgBox("Decoder failed for " fn)
					break
				} else {
          	     	if !IsSet(f)
						f:=FileOpen(fn ".jpg","w")
                    	bytes := DllCall("jxl\JxlDecoderReleaseJPEGBuffer","Ptr",j)
					f.RawWrite(o,o.size-bytes)
     	               if r!=6
          	          	break
               	}
			}
	          if IsSet(f)
				f.Close()
          } 
		DllCall("jxl\JxlDecoderDestroy","Ptr",j)
	}

}

showjxl(fn) {
	wnd := Gui('Resize')
	wnd.MarginX := wnd.MarginY := 0
	wnd.AddPicture(, 'HBITMAP: ' CreateBitmap())
	wnd.Show()

	CreateBitmap() {
		buf := FileRead(fn, "RAW")
		dec := DllCall("jxl.dll\JxlDecoderCreate", "ptr", 0,"Ptr")
		DllCall("jxl.dll\JxlDecoderSubscribeEvents", "ptr", dec, "uint", 64 | 4096, "int")	; JXL_DEC_BASIC_INFO | JXL_DEC_FULL_IMAGE
		DllCall("jxl.dll\JxlDecoderSetInput", "ptr", dec, "ptr", buf, "uint", buf.size, "int")
		DllCall("jxl.dll\JxlDecoderCloseInput", "ptr", dec, "Ptr")
		loop 4 {
          	r := DllCall("jxl.dll\JxlDecoderProcessInput", "ptr", dec, "Ptr")
 			switch r {
				case 64:	; JXL_DEC_BASIC_INFO:
					info := Buffer(2048, 0)
					DllCall("jxl.dll\JxlDecoderGetBasicInfo", "ptr", dec, "ptr", info, "int")
					w := NumGet(info, 4, "uint")
					h := NumGet(info, 8, "uint")
                         ; size, w, h, planes, bitcount, compression (BI_BITFIELDS = 3)
					NumPut("uint", 40, "int", w, "int", -h, "UShort", 1, "UShort",32,"int",3, BITMAPINFO:= Buffer(52,0))
                         NumPut("uint", 0x000000FF, "uint", 0x0000FF00, "uint", 0x00FF0000, BITMAPINFO, 40)
                         hDC := DllCall('GetDC', 'Ptr', 0, 'Ptr')
					hBitmap := DllCall('CreateDIBSection','Ptr',hDC,'Ptr',BITMAPINFO,'UInt',0,'PtrP',&pBits:=0,'Ptr',0,'UInt',0,'Ptr')
				case 5:	; JXL_DEC_NEED_IMAGE_OUT_BUFFER
					JxlPixelFormat := Buffer(24, 0)
				     ; channels: 1: single-channel data, e.g. grayscale or a single extra channel
					;		  2: single-channel + alpha
					;		  3: trichromatic, e.g. RGB
					;		  4: trichromatic + alpha
				     ; data type: JXL_TYPE_FLOAT = 0, JXL_TYPE_UINT8 = 2, JXL_TYPE_UINT16 = 3, JXL_TYPE_FLOAT16 = 5
			     	; endianness: JXL_NATIVE_ENDIAN = 0, JXL_LITTLE_ENDIAN = 1, JXL_BIG_ENDIAN = 2
				     ; align:
					NumPut("int", 4, "int", 2, JxlPixelFormat)
					DllCall("jxl.dll\JxlDecoderSetImageOutBuffer", "ptr", dec, "ptr", JxlPixelFormat, "ptr", pbits, "uint64", w*h*4, "int")
				default: break
               }
		}
		DllCall("jxl.dll\JxlDecoderDestroy", "ptr", dec, "Ptr")
		return hBitmap
	}
}

;pixel := jxl_pix(pic), pw := pixel.w, ph := pixel.h
;DllCall("Gdiplus.dll\GdipCreateBitmapFromScan0", "Int", pw, "Int", ph, "Int", ((pw * 32 + 31) & ~31) >> 3, "UInt", 0x26200A, "Ptr", pixel.ptr, "PtrP", &pBitmap := 0)

jxl_pix(buf, opt := "") { ; https://github.com/libjxl/libjxl/releases
	static dll_dir := ".\",
		jth_hd := DllCall("GetModuleHandle", "str", "jxl_threads.dll")
		|| (DllCall("SetDllDirectory", "Str", dll_dir), DllCall("LoadLibrary", "str", dll_dir "\jxl.dll", "Cdecl UPtr"),
			DllCall("LoadLibrary", "str", dll_dir "\jxl_threads.dll", "Cdecl UPtr")),
		JxlResizableParallelRunner := DllCall("GetProcAddress", "Ptr", jth_hd, "AStr", "JxlResizableParallelRunner", "ptr"),
		JXL_DEC_FRAME := 0x400,
		JXL_DEC_FULL_IMAGE := 0x1000,
		JXL_DEC_NEED_IMAGE_OUT_BUFFER := 5,
		JXL_DEC_NEED_MORE_INPUT := 2,
		JXL_DEC_ERROR := 1,
		JXL_DEC_BASIC_INFO := 0x40,
		JXL_DEC_COLOR_ENCODING := 0x100,
		JXL_DEC_FRAME_PROGRESSION := 0x8000,
		JXL_DEC_SUCCESS := 0


	if buf is String
		buf := FileRead(buf, "RAW")

	runn := DllCall("jxl_threads.dll\JxlResizableParallelRunnerCreate", "ptr", 0, "int", 8, "Ptr")
	dec := DllCall("jxl.dll\JxlDecoderCreate", "ptr", 0, "Ptr")

	DllCall("jxl.dll\JxlDecoderSubscribeEvents", "ptr", dec, "uint", JXL_DEC_BASIC_INFO | JXL_DEC_FULL_IMAGE, "int")

	DllCall("jxl.dll\JxlDecoderSetParallelRunner", "ptr", dec, "ptr", JxlResizableParallelRunner, "ptr", runn, "int")
	DllCall("jxl.dll\JxlDecoderSetInput", "ptr", dec, "ptr", buf, "uint", buf.size, "int")
	DllCall("jxl.dll\JxlDecoderCloseInput", "ptr", dec, "Ptr")

	fo := Buffer(24, 0)
     ; JxlPixelFormat:
     ; channels: 1: single-channel data, e.g. grayscale or a single extra channel
	;		  2: single-channel + alpha
	;		  3: trichromatic, e.g. RGB
	;		  4: trichromatic + alpha
     ; data type: JXL_TYPE_FLOAT = 0, JXL_TYPE_UINT8 = 2, JXL_TYPE_UINT16 = 3, JXL_TYPE_FLOAT16 = 5
     ; endianness: JXL_NATIVE_ENDIAN = 0, JXL_LITTLE_ENDIAN = 1, JXL_BIG_ENDIAN = 2
     ; align:
	NumPut("int", 4, "int", 2, fo)

	loop 4
	{
		switch status := DllCall("jxl.dll\JxlDecoderProcessInput", "ptr", dec, "Ptr")
		{
			case JXL_DEC_BASIC_INFO:	;64
				info := Buffer(2048, 0)
				DllCall("jxl.dll\JxlDecoderGetBasicInfo", "ptr", dec, "ptr", info, "int")
				pw := NumGet(info, 4, "uint")
				ph := NumGet(info, 8, "uint")
				th := DllCall("jxl_threads.dll\JxlResizableParallelRunnerSuggestThreads", "uint64", pw, "uint64", ph, "int")
				DllCall("jxl_threads.dll\JxlResizableParallelRunnerSetThreads", "ptr", runn, "uint64", th, "Ptr")

			case JXL_DEC_NEED_IMAGE_OUT_BUFFER: ;5
				DllCall("jxl.dll\JxlDecoderImageOutBufferSize", "ptr", dec, "ptr", fo, "uintp", &sz := 0, "int")
				out := Buffer(sz, 0), out.w := pw, out.h := ph
				DllCall("jxl.dll\JxlDecoderSetImageOutBuffer", "ptr", dec, "ptr", fo, "ptr", out, "uint64", sz, "int")

			case JXL_DEC_FULL_IMAGE: ;4096- One frame
				break
			default:
				break
		}
	}

	DllCall("jxl.dll\JxlDecoderDestroy", "ptr", dec, "Ptr")
	DllCall("jxl_threads.dll\JxlResizableParallelRunnerDestroy", "ptr", runn, "Ptr")
	return out
}