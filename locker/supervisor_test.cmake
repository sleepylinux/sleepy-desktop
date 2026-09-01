execute_process(
    COMMAND "${SUPERVISOR}" "${CLEAN_CHILD}"
    RESULT_VARIABLE supervisor_result)

if(NOT supervisor_result EQUAL 1)
    message(FATAL_ERROR
        "supervisor must map an unexpected clean child exit to exactly 1; got ${supervisor_result}")
endif()
