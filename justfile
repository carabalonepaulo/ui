test:
    @odin run test

unit:
    @odin test tests -collection:ui=ui -define:ODIN_TEST_THREADS=1

check:
    @odin check ui -no-entry-point
