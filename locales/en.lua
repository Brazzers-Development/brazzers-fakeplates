local Translations = {
    error = {
        already_has_plate = 'This vehicle already has another plate over this plate',
        does_not_have_fakeplate = 'This vehicle does not contain any extra plate on it',
    },
}

Lang = Locale:new({
    phrases = Translations,
    warnOnMissing = true
})
