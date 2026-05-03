"""Smoke test — exists only to give pytest something to find on the
first CI run, before real tests land in HW6 Part B."""


def test_truth():
    assert True


def test_addition():
    assert 1 + 1 == 2
