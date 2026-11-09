@{
    # FocusBlocker to zestaw skryptów, nie moduł publikowany w PowerShell Gallery,
    # więc pomijamy reguły dotyczące wyłącznie publicznego API modułów.
    ExcludeRules = @(
        # Menu w terminalu celowo pisze kolorowy tekst na konsolę
        'PSAvoidUsingWriteHost'
        # Wewnętrzne funkcje pomocnicze - nazwy po polsku-angielsku, bez -WhatIf
        'PSUseApprovedVerbs'
        'PSUseSingularNouns'
        'PSUseShouldProcessForStateChangingFunctions'
        'PSAvoidUsingPositionalParameters'
        # Puste catch są celowe: zapis do dziennika i zamykanie odpowiedzi HTTP
        # nie mogą przerwać działania blokady
        'PSAvoidUsingEmptyCatchBlock'
        # $FB_Dir ustawiane przed dot-source lib.ps1 - analizator tego nie widzi
        'PSUseDeclaredVarsMoreThanAssignments'
    )
}
