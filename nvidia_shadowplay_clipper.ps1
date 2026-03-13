$environmentVariable_FFMPEG = "FFMPEG_PATH"

If (${Env:$environmentVariable_FFMPEG}){
	$FFMPEG_filePath = $Env:environmentVariable_FFMPEG
	
} Else {
	$FFMPEG_filePath = Read-Host "`nEnter the path to FFMPEG.exe".Trim('"', "'")
	Write-Host "`tRemembering path for next time..."
	setx $environmentVariable_FFMPEG $FFMPEG_filePath > $Null
}

$environmentVariable_NVIDIA = "NVIDIA_LAST_PATH"

While ($True) {
    Do {
        If (${Env:$environmentVariable_NVIDIA}){
			$folderPathInput = Read-Host "`nEnter input folder path (leave blank to re-use '${Env:$environmentVariable_NVIDIA}')".Trim('"', "'")
			
			If ($folderPathInput){
				$folderPath = $folderPathInput
			} Else {
				$folderPath = ${Env:$environmentVariable_NVIDIA}
			}
		} Else {
			$folderPath = Read-Host "`nEnter input folder path".Trim('"', "'")
		}
        
        If (-Not (Test-Path $folderPath -PathType Container)) {
            Write-Host "`tFolder Not found. Please try again." -ForegroundColor Red
        }
		
    } While (-Not (Test-Path $folderPath -PathType Container))
	
	If (${Env:$environmentVariable_NVIDIA} -NE $folderPath) {
		Write-Host "`tRemembering path for next time..."
		setx $environmentVariable_NVIDIA $folderPath > $Null
		${Env:$environmentVariable_NVIDIA} = $folderPath
	}

    $supportedExtensions = @(".mp4", ".mkv", ".avi", ".mov", ".flv", ".wmv")

    $videoFiles = Get-ChildItem -Path $folderPath -File |
                  Where-Object {
                      ($supportedExtensions -Contains $_.Extension.ToLower()) -And
                      ($_.BaseName -Match 'DVR$') # Unprocessed.
                  }
				  # "Fallout - New Vegas 2025.11.21 - 22.26.01.21.DVR.mp4"

    If (-Not $videoFiles) {
        Write-Host "`tNo unprocessed video files found in folder." -ForegroundColor Yellow
        Continue
    }

    Write-Host "`tFound $($videoFiles.Count) unprocessed video file(s) to process."

    For ($i = 0; $i -LT $videoFiles.Count; $i++) {
        $file = $videoFiles[$i]
		
        Write-Host "`nProcessing file $($i + 1) of $($videoFiles.Count): '$($file.Name)'"

        Start-Process $file.FullName

        While ($True) {
            $action = Read-Host "`tTrim or delete or none? (t/d/n)"
            
			If ($action -NotMatch '^[TtDdNn]$') {
                Write-Host "`tEnter 't' or 'd' or 'n'" -ForegroundColor Red
            } Else {
				Break
			}
        }

        If ($action -Match '^[Dd]$') {
            $shell = New-Object -ComObject Shell.Application
            $shell.Namespace(0xA).MoveHere($file.FullName)
            Write-Host "`tDeleted to Recycle Bin"
            Continue
        }
		
		If ($action -Match '^[Nn]$') {
            Continue
        }

        Do {
			While ($True){
				$parameters = (Read-Host "`n`tEnter start time and description and optional end time separated by pipes (e.g., 19:30`|Some description`|19:45)").Trim().Split("|")
				
				If (-Not $parameters){
					Write-Host "`tInput parameters required" -ForegroundColor Red
					Continue
				}
				
				$startTime = $parameters[0]
				If ($startTime.Length -Eq 5){
					$startTime = "00:$startTime"
				}
				If (-Not $startTime -Or $startTime -NotMatch '^\d{2}:\d{2}:\d{2}$') {
					Write-Host "`tInvalid or empty start time" -ForegroundColor Red
					Continue
				}
				
				$description = $parameters[1]
                If (-Not $description) {
                    Write-Host "`tDescription required" -ForegroundColor Red
					Continue
                }
				
				$endTime = $parameters[2]
				If ($endTime){
					If ($endTime.Length -Eq 5){
						$endTime = "00:$endTime"
					}
					If (-Not $endTime -Or $endTime -NotMatch '^\d{2}:\d{2}:\d{2}$') {
						Write-Host "`tInvalid or empty end time" -ForegroundColor Red
						Continue
					}
				}
				
				Break
			}
			

            $description = $description -Replace '[\\/:*?"<>|]', "_"
			
			$outputFileBaseName = $file.BaseName -Replace "\.", "-" -Replace " - ", " " -Replace "-\d{2,3}-DVR", ""
            $outputFileName = "$outputFileBaseName - $description$($file.Extension)"
			
			
            $outputPath = Join-Path $file.DirectoryName $outputFileName

            $FFMPEG_filePathArgs = @('-y', '-hide_banner', '-loglevel', 'error', '-i', $file.FullName, '-ss', $startTime, '-map', '0')
            If ($endTime) { $FFMPEG_filePathArgs += @('-to', $endTime) }
            $FFMPEG_filePathArgs += @('-c', 'copy', $outputPath)

            & $FFMPEG_filePath @ffmpegArgs > $null 2>&1
            Start-Process $outputPath

			Write-Host "`tCreated '$outputFileName'" -ForegroundColor Green
			
			Do {
                $keep = Read-Host "`tKeep clip? (y/n)"
                If ($keep -NotMatch '^[YyNn]$') {
                    Write-Host "`tEnter 'y' or 'n'" -ForegroundColor Red
                }
            } While ($keep -NotMatch '^[YyNn]$')
			
			If ($keep -Match '^[Nn]') {
				$shell = New-Object -ComObject Shell.Application
				$shell.Namespace(0xA).MoveHere($outputPath)
				Write-Host "`tDeleted to Recycle Bin"
			}

            Do {
                $another = Read-Host "`tCreate another clip? (y/n)"
                If ($another -NotMatch '^[YyNn]$') {
                    Write-Host "`tEnter 'y' or 'n'." -ForegroundColor Red
                }
            } While ($another -NotMatch '^[YyNn]$')
			
        } While ($another -Match '^[Yy]$')

        Do {
            $delete = Read-Host "`tDelete original file? (y/n)"
            If ($delete -NotMatch '^[YyNn]$') {
                Write-Host "`tEnter 'y' or 'n'." -ForegroundColor Red
            }
        } While ($delete -NotMatch '^[YyNn]$')

        If ($delete -Match '^[Yy]') {
            $shell = New-Object -ComObject Shell.Application
            $shell.Namespace(0xA).MoveHere($file.FullName)
            Write-Host "`tDeleted to Recycle Bin"
        } Else {
            Write-Host "`tKept"
        }
    }
}
