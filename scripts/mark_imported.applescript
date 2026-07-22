-- mark_imported.applescript
--
-- Reads ~/notes_import_log.txt and moves each successfully imported
-- note into the "Imported" folder in Apple Notes.
--
-- Run after verifying import_to_zk.py completed successfully:
--   osascript mark_imported.applescript

-- Read the import log
set logPath to (path to home folder as string) & "notes_import_log.txt"

tell application "System Events"
    if not (exists file logPath) then
        log "ERROR: ~/notes_import_log.txt not found. Run import_to_zk.py first."
        return
    end if
end tell

-- Read titles from log file
set fileRef to open for access file logPath
set logContents to read fileRef
close access fileRef

set AppleScript's text item delimiters to linefeed
set importedTitles to text items of logContents
set AppleScript's text item delimiters to ""

-- Remove empty lines
set cleanTitles to {}
repeat with t in importedTitles
    if (t as string) is not "" then
        set end of cleanTitles to (t as string)
    end if
end repeat

log "Titles to move: " & (count of cleanTitles)

tell application "Notes"
    -- Find the Imported folder
    set importedFolder to missing value
    repeat with f in folders
        if name of f is "Imported" then
            set importedFolder to f
            exit repeat
        end if
    end repeat

    if importedFolder is missing value then
        log "ERROR: 'Imported' folder not found. Run export_notes.applescript first."
        return
    end if

    -- Build a list of {note, title} pairs to move BEFORE touching anything
    -- This avoids the iterator invalidation error
    set notesToMove to {}
    set allFolders to every folder

    repeat with theFolder in allFolders
        if name of theFolder is not "Imported" then
            set folderNotes to every note of theFolder
            repeat with theNote in folderNotes
                try
                    set noteTitle to name of theNote
                    repeat with targetTitle in cleanTitles
                        if noteTitle is (targetTitle as string) then
                            set end of notesToMove to theNote
                            exit repeat
                        end if
                    end repeat
                end try
            end repeat
        end if
    end repeat

    log "Found " & (count of notesToMove) & " notes to move."

    -- Now move them all
    set movedCount to 0
    repeat with theNote in notesToMove
        try
            move theNote to importedFolder
            set movedCount to movedCount + 1
        on error errMsg
            log "Could not move note: " & errMsg
        end try
    end repeat

    log "Done. Moved: " & movedCount & " notes to 'Imported' folder."
    log "You can delete the 'Imported' folder manually when satisfied."
end tell