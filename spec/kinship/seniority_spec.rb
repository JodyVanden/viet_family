require "rails_helper"

# T1.3 — one precedence rule for sibling seniority (drives bác vs. chú and
# anh/chị vs. em): reliable birth_date wins; else birth_order; else unknown.
RSpec.describe "Kinship.seniority" do
  def person(id, birth_date: nil, birth_order: nil)
    Kinship::Person.new(id: id, name: id.to_s, gender: :male,
                        birth_date: birth_date && Date.parse(birth_date),
                        birth_order: birth_order)
  end

  it "uses birth_date when both are present" do
    older = person(:a, birth_date: "1980-01-01")
    younger = person(:b, birth_date: "1985-01-01")
    expect(Kinship.seniority(older, younger)).to eq(:older)
    expect(Kinship.seniority(younger, older)).to eq(:younger)
  end

  it "reports :same for identical birth dates" do
    a = person(:a, birth_date: "1980-01-01")
    b = person(:b, birth_date: "1980-01-01")
    expect(Kinship.seniority(a, b)).to eq(:same)
  end

  it "falls back to birth_order when a date is missing" do
    first = person(:a, birth_order: 1)
    second = person(:b, birth_order: 3)
    expect(Kinship.seniority(first, second)).to eq(:older)
    expect(Kinship.seniority(second, first)).to eq(:younger)
  end

  it "prefers dates over birth_order when both dates exist" do
    # birth_order disagrees with dates; dates must win.
    older_by_date = person(:a, birth_date: "1980-01-01", birth_order: 5)
    younger_by_date = person(:b, birth_date: "1985-01-01", birth_order: 1)
    expect(Kinship.seniority(older_by_date, younger_by_date)).to eq(:older)
  end

  it "returns :unknown when neither dates nor orders are comparable" do
    a = person(:a)
    b = person(:b, birth_order: 2)
    expect(Kinship.seniority(a, b)).to eq(:unknown)
  end

  it "exposes senior? as a boolean shortcut for :older" do
    older = person(:a, birth_date: "1980-01-01")
    younger = person(:b, birth_date: "1985-01-01")
    expect(Kinship.senior?(older, younger)).to be(true)
    expect(Kinship.senior?(younger, older)).to be(false)
  end
end
