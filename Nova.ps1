# Avoid SSL failures and use tls 1.2

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

clear

$disk = "c:\"
$dir  = "Videos\"
$dest = "Z:\PBS\"

#Below is my hashtable declaration for $fileCollection. This is where I store my 
#partial urls ($urlPrefix) and video titles ($file) as well as the program name ($src)

. "C:\Movies\uriCollection.ps1"

$fileCollection | ForEach-Object {

    [string]$urlPrefix  = $_.urlPrefix
    [string]$file = $_.file
    [string]$src  = $_.src
    [string]$season = "Season " + $($([string]$file -Split 'e')[0] -Split 's')[1]             #Turn s38e12 into "Season 38"

    if (Test-Path "$dest$src\$season\$src.$file.mkv"){

        Write-Host("File exists, skipping:")
        Write-Host("$dest$src\$season\$src.$file.mkv`r`n`r`n")

    } else {

        #Make sure directories are in place because later on ffmpeg will not create them and
        #will error out.
    
        Remove-Item -Path "$disk$dir$file"     -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
        Remove-Item -Path "$disk$dir$file$ext"          -Force -ErrorAction SilentlyContinue | Out-Null

        new-item -Force -Path "$dest"                     -ItemType directory | Out-Null
        new-item -Force -Path "$dest$src\"                -ItemType directory | Out-Null
        new-item -Force -Path "$dest$src\$season"         -ItemType directory | Out-Null
        new-item -Force -Path "$disk$dir$file"            -ItemType directory | Out-Null
        new-item -Force -Path "$disk$dir$file"            -ItemType directory | Out-Null
        new-item -Force -Path "$disk$dir$file\concat.txt" -ItemType file      | Out-Null

        Write-Host("$dest$src\$season\$src.$file")

        $ffmpegLocation = "c:\Bigsky\ffmpeg.exe"
        $ext            = ".ts"
        $i              = 1 
        $errors         = 0

        #Format the 5 digit padded .ts file numbering scheme that is used here and put the full
        #url together.

        do{

            $num = "{0:00000}" -f $i
            $url = "$urlPrefix$num$ext"

            #Start downloading each segment of the HLS mp2t stream. Error out when the video 
            #has ended and the url's are no longer found. Also build the concat.txt file to
            #use ffmpeg to put these segments back together.

            try{

                Invoke-WebRequest -Uri $url -OutFile "$disk$dir$file\$file.$num$ext"
                Add-Content $disk$dir$file\concat.txt "file '$disk$dir$file\$file.$num$ext'"

            }catch{

                $errors = 1

            }

            $i++

        }while($errors -eq 0)

        #Put the .ts files together with the concat demuxer using the list, concat.txt. Then
        #put the resulting .ts file into a .mkv container.

        & $ffmpegLocation -hide_banner -y -safe 0 -f concat -i $disk$dir$file\concat.txt -c copy $disk$dir$file$ext
        & $ffmpegLocation -y -i $disk$dir$file$ext -c:v libx264 -c:a copy $disk$dir$file.mkv

        #Unlink all of the .ts files and the compilation .ts file as well as the concat.txt file.

        Remove-Item -Path "$disk$dir$file" -Recurse -Force | Out-Null
        Remove-Item -Path "$disk$dir$file$ext"      -Force | Out-Null

        #Move the .mkv file to the network storage location

        Move-Item -Path "$disk$dir$file.mkv" -Destination "$dest$src\$season\$src.$file.mkv" -Force
    }
}

#1..$end | foreach{
#    $num = "{0:00000}" -f $_
#    $url = "$urlPrefix$num$ext"
#    Invoke-WebRequest -Uri $url -OutFile "$disk$file\$file.$num$ext"
#    Add-Content $disk$file\concat.txt "file '$disk$file\$file.$num$ext'"
#                   
#    $i++
#
#}