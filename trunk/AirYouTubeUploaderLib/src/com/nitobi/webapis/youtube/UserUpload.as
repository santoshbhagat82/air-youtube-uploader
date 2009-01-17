package com.nitobi.webapis.youtube
{
	import flash.filesystem.File;
	
	public class UserUpload
	{

		public var name:String;
		public var uid:String;
		public var file:File;
		public var fileName:String;
		
		public function UserUpload()
		{
		}
		
		public static function create(filePath:String):UserUpload
		{
			var lfi:UserUpload = new UserUpload();
			var file:File = new File(filePath);
			lfi.name = file.name;
			lfi.uid	= file.url;
			lfi.fileName = file.name;
			lfi.file = file;
			return lfi;
		}

	}
}