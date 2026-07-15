# Kinship — pure, framework-free domain logic for Vietnamese kinship terms.
#
# The word used for a relative depends on WHO is viewing (paternal vs. maternal
# side, seniority, gender). Nothing in this namespace may reference ActiveRecord,
# Rails, or perform I/O — that is what keeps it exhaustively testable and portable
# to a future mobile app. See docs/SPEC.md §2.
module Kinship
end
