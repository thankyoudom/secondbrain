-- export_notes.applescript
--
-- Exports all Apple Notes to ~/notes_export.json
-- Detects attachments (images, audio, files) per note.
-- After Python import runs successfully, run mark_imported.applescript
-- to move processed notes into the "Imported" folder.
--
-- Run with: osascript export_notes.applescript

on escapeForJSON(theText)
	set theText to my replaceText(theText, "\\", "\\\\")
	set theText to my replaceText(theText, "\"", "\\\"")
	set theText to my replaceText(theText, return, "\\n")
	set theText to my replaceText(theText, linefeed, "\\n")
	set theText to my replaceText(theText, tab, "\\t")
	return theText
end escapeForJSON

on replaceText(theText, searchString, replacementString)
	set AppleScript's text item delimiters to searchString
	set theItems to text items of theText
	set AppleScript's text item delimiters to replacementString
	set theText to theItems as string
	set AppleScript's text item delimiters to ""
	return theText
end replaceText

on formatDate(theDate)
	set y to year of theDate as string
	set m to month of theDate as integer
	set d to day of theDate as integer
	if m < 10 then set m to "0" & m
	if d < 10 then set d to "0" & d
	return y & "-" & m & "-" & d
end formatDate

tell application "Notes"
	-- Ensure "Imported" folder exists so mark_imported.applescript can use it
	set importedFolderName to "Imported"
	set importedFolderExists to false
	repeat with f in folders
		if name of f is importedFolderName then
			set importedFolderExists to true
			exit repeat
		end if
	end repeat
	if not importedFolderExists then
		make new folder with properties {name:importedFolderName}
		log "Created 'Imported' folder in Notes"
	end if

	set jsonOutput to "["
	set firstNote to true
	set noteCount to 0
	set skippedCount to 0

	repeat with theFolder in folders
		set folderName to name of theFolder

		-- Skip the Imported folder itself so we never re-process
		if folderName is importedFolderName then
		else
			repeat with theNote in notes of theFolder
				try
					set noteTitle to name of theNote
					set noteBody to plaintext of theNote
					set noteCreated to creation date of theNote
					set noteModified to modification date of theNote

					-- Detect embedded attachments (images, audio, PDFs, etc.)
					set attachCount to count of attachments of theNote
					if attachCount > 0 then
						set hasAttachStr to "true"
					else
						set hasAttachStr to "false"
					end if

					set escapedTitle to my escapeForJSON(noteTitle)
					set escapedBody to my escapeForJSON(noteBody)
					set escapedFolder to my escapeForJSON(folderName)
					set createdStr to my formatDate(noteCreated)
					set modifiedStr to my formatDate(noteModified)

					if not firstNote then
						set jsonOutput to jsonOutput & ","
					end if

					set jsonOutput to jsonOutput & "{" & ¬
						"\"title\":\"" & escapedTitle & "\"," & ¬
						"\"folder\":\"" & escapedFolder & "\"," & ¬
						"\"body\":\"" & escapedBody & "\"," & ¬
						"\"created\":\"" & createdStr & "\"," & ¬
						"\"modified\":\"" & modifiedStr & "\"," & ¬
						"\"has_attachments\":" & hasAttachStr & ¬
						"}"

					set firstNote to false
					set noteCount to noteCount + 1
				on error
					set skippedCount to skippedCount + 1
				end try
			end repeat
		end if
	end repeat

	set jsonOutput to jsonOutput & "]"
end tell

-- Write JSON to ~/notes_export.json
set outputPath to (path to home folder as string) & "notes_export.json"
set fileRef to open for access file outputPath with write permission
set eof of fileRef to 0
write jsonOutput to fileRef
close access fileRef

log "Done. Exported: " & noteCount & " | Skipped (unreadable): " & skippedCount
log "Output: ~/notes_export.json"
log "Next step: python3 import_to_zk.py --zk-root ~/Documents/repos/secondbrain"
