# IconTools.ps1 - extrae iconos de DLL/ICO y dibuja cursores (.cur/.ani) en imagenes.
# Lo usan catalog\Build-IconPreviews.ps1 y catalog\Build-CursorPreviews.ps1.
Add-Type -AssemblyName System.Drawing
if (-not ('ZKCustom.IconNative' -as [type])) {
    Add-Type -Namespace ZKCustom -Name IconNative -MemberDefinition @'
[DllImport("user32.dll", CharSet = CharSet.Unicode)]
public static extern uint PrivateExtractIcons(string file, int index, int cx, int cy, System.IntPtr[] icons, uint[] ids, uint n, uint flags);
[DllImport("user32.dll")] public static extern bool DestroyIcon(System.IntPtr h);
[DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern System.IntPtr LoadImage(System.IntPtr hinst, string name, uint type, int cx, int cy, uint load);
[DllImport("user32.dll")] public static extern bool DrawIconEx(System.IntPtr hdc, int x, int y, System.IntPtr h, int cx, int cy, uint step, System.IntPtr brush, uint flags);
[DllImport("kernel32.dll", CharSet = CharSet.Unicode)] public static extern System.IntPtr LoadLibraryEx(string file, System.IntPtr h, uint flags);
[DllImport("kernel32.dll")] public static extern bool FreeLibrary(System.IntPtr h);
[DllImport("kernel32.dll", CharSet = CharSet.Unicode)] public static extern System.IntPtr FindResource(System.IntPtr h, System.IntPtr name, System.IntPtr type);
'@
}

function Get-IconBitmap {
    <# Icono de un archivo (dll/exe/ico) como Bitmap con transparencia. $Id > 0 = id de recurso; $Index = posicion. #>
    param([string]$File, [int]$Id = 0, [int]$Index = 0, [int]$Size = 96)
    $h = New-Object IntPtr[] 1; $ids = New-Object uint32[] 1
    $idx = if ($Id -gt 0) { -$Id } else { $Index }
    $n = [ZKCustom.IconNative]::PrivateExtractIcons($File, $idx, $Size, $Size, $h, $ids, 1, 0)
    if ($n -eq 0 -or $n -eq [uint32]::MaxValue -or $h[0] -eq [IntPtr]::Zero) { return $null }
    try { $ico = [Drawing.Icon]::FromHandle($h[0]); $bmp = $ico.ToBitmap(); $ico.Dispose(); $bmp } finally { [void][ZKCustom.IconNative]::DestroyIcon($h[0]) }
}

function Test-IconResource {
    # Comprueba si una DLL de recursos trae el grupo de iconos con ese id (RT_GROUP_ICON = 14)
    param([string]$File, [int]$Id)
    $lib = [ZKCustom.IconNative]::LoadLibraryEx($File, [IntPtr]::Zero, 0x22)   # DATAFILE | IMAGE_RESOURCE
    if ($lib -eq [IntPtr]::Zero) { return $false }
    try { [ZKCustom.IconNative]::FindResource($lib, [IntPtr]$Id, [IntPtr]14) -ne [IntPtr]::Zero } finally { [void][ZKCustom.IconNative]::FreeLibrary($lib) }
}

function Get-CursorBitmap {
    <# Dibuja un .cur o .ani (primer fotograma) sobre un fondo, a un tamano dado #>
    param([string]$File, [int]$Size = 64, [Drawing.Color]$Back)
    $h = [ZKCustom.IconNative]::LoadImage([IntPtr]::Zero, $File, 2, $Size, $Size, 0x10)   # IMAGE_CURSOR, LR_LOADFROMFILE
    if ($h -eq [IntPtr]::Zero) { return $null }
    $bmp = New-Object Drawing.Bitmap $Size, $Size
    $g = [Drawing.Graphics]::FromImage($bmp); $g.Clear($Back)
    $hdc = $g.GetHdc()
    try { [void][ZKCustom.IconNative]::DrawIconEx($hdc, 0, 0, $h, $Size, $Size, 0, [IntPtr]::Zero, 3) } finally { $g.ReleaseHdc($hdc); $g.Dispose(); [void][ZKCustom.IconNative]::DestroyIcon($h) }
    $bmp
}
