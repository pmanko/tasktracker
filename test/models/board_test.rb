# frozen_string_literal: true

require 'test_helper'

class BoardTest < ActiveSupport::TestCase
  test 'get short time for board from this year' do
    date = Date.today
    board = Board.new(start_date: date, end_date: date)
    assert_equal "#{date.strftime('%m/%d')} to #{date.strftime('%m/%d')}", board.short_time
  end

  test 'get short time for board from last year' do
    date = Date.today - 1.year
    board = Board.new(start_date: date, end_date: date)
    assert_equal "#{date.strftime('%m/%d/%Y')} to #{date.strftime('%m/%d/%Y')}", board.short_time
  end
end
