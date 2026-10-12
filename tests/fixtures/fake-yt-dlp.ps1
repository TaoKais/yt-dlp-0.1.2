if ($args[0] -ne '--flat-playlist' -or $args[1] -ne '--print' -or
    $args[2] -ne 'https://www.youtube.com/watch?v=%(id)s') { exit 2 }
Write-Output 'https://www.youtube.com/watch?v=TEST_ID'
Write-Output 'https://www.youtube.com/watch?v=SECOND_ID'
exit 0
