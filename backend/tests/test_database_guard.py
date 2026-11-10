"""The integration tests drop every table, so conftest refuses databases that are not clearly disposable."""

from conftest import unsafe_test_database_reason

# Placeholder credentials only, as in the *.env.example files.
DEV = "postgresql+psycopg://agritwin:change-me@localhost:5433/agritwin"
TEST = "postgresql+psycopg://agritwin:change-me@localhost:5433/agritwin_test"


def test_separate_test_database_is_accepted():
    assert unsafe_test_database_reason(TEST, DEV) is None


def test_database_without_test_suffix_is_refused():
    reason = unsafe_test_database_reason(DEV, None)
    assert reason is not None and "'agritwin'" in reason


def test_same_database_as_dev_is_refused():
    shared = "postgresql+psycopg://agritwin:change-me@localhost:5433/shared_test"
    reason = unsafe_test_database_reason(shared, shared)
    assert reason is not None and "both point" in reason


def test_reason_never_contains_the_password():
    assert "change-me" not in (unsafe_test_database_reason(DEV, None) or "")


def test_no_test_url_means_nothing_to_check():
    assert unsafe_test_database_reason(None, DEV) is None
