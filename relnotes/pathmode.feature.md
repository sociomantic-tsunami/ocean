* `ocean.io.FilePath_tango`, `ocean.io.Path`

  Methods `createFile`/`createFolder` in these two modules have learned
  to accept mode for the new file/directory as a optional argument. They default
  to their previous values, 0660 and 0777, respectively.
