-- mark_imported.applescript
--
-- Reads ~/notes_import_log.json (written by import_to_zk.py)
-- and moves each successfully imported note into the "Imported" folder
-- in Apple Notes. This is non-destructive — notes are moved, not deleted.
--
-- Run ONLY after verifying import_to_zk.py completed successfully:
--   osascript mark_imported.applescript

on readFile(filePath)
	set fileRef to open for access file filePath
	set fileContents to read fileRef
	close access fileRef
	return fileContents
end readFile

-- Parse a flat list of note titles from the import log
-- The Python script writes one title per line to ~/notes_import_log.txt
on splitLines(theText)
	set AppleScript's text item delimiters to linefeed
	set theLines to text items of theText
	set AppleScript's text item delimiters to ""
	return theLines
end splitLines

set logPath to (path to home folder as string) & "notes_import_log.txt"

-- Check log file exists
tell application "System Events"
	if not (exists file logPath) then
		log "ERROR: ~/notes_import_log.txt not found."
		log "Run import_to_zk.py first."
		return
	end if
end tell

set logContents to my readFile(logPath)
set importedTitles to my splitLines(logContents)

set movedCount to 0
set notFoundCount to 0

tell application "Notes"
	set importedFolder to missing value

	-- Find the Imported folder
	repeat with f in folders
		if name of f is "Imported" then
			set importedFolder to f
			exit repeat
		end if
	end repeat

	if importedFolder is missing value then
		log "ERROR: 'Imported' folder not found in Notes. Run export_notes.applescript first."
		return
	end if

	-- For each title in the log, find and move the note
	repeat with noteTitle in importedTitles
		set titleStr to noteTitle as string
		if titleStr is not "" then
			set foundNote to missing value

			repeat with theFolder in folders
				if name of theFolder is not "Imported" then
					repeat with theNote in notes of theFolder
						try
							if name of theNote is titleStr then
								set foundNote to theNote
								exit repeat
							end if
						end try
					end repeat
				end if
				if foundNote is not missing value then exit repeat
			end repeat

			if foundNote is not missing value then
				move foundNote to importedFolder
				set movedCount to movedCount + 1
				log "Moved: " & titleStr
			else
				set notFoundCount to notFoundCount + 1
				log "Not found (may already be moved): " & titleStr
			end if
		end if
	end repeat
end tell

log ""
log "Done. Moved: " & movedCount & " | Not found: " & notFoundCount
log "Notes are in the 'Imported' folder. Delete it manually when satisfied."
