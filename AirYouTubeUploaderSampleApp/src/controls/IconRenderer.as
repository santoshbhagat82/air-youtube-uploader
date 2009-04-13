package controls
{
	import flash.display.Bitmap;
	import flash.display.BitmapData;
	
	import mx.core.UIComponent;

	public class IconRenderer extends mx.core.UIComponent
	{
		
		private var _bmpData:BitmapData;
		private var bitmap:Bitmap;
		
		public function IconRenderer()
		{
			super();
		}
		
		public function set bitmapData(value:BitmapData):void
		{
			this._bmpData = value;
			this.invalidateDisplayList();
		}
		
		protected override function updateDisplayList(unscaledWidth:Number,unscaledHeight:Number):void
		{
			if(bitmap != null)
			{
				this.removeChild(bitmap);
			}
			if(_bmpData != null)
			{
				bitmap = new Bitmap(_bmpData);
				this.addChildAt(bitmap,0);
				bitmap.x = (unscaledWidth - bitmap.width) / 2;
				bitmap.y = (unscaledHeight - bitmap.height) / 2;
			}
		}
		

	}
}