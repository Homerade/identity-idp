require 'rails_helper'

feature 'doc auth send link step' do
  include IdvStepHelper
  include DocAuthHelper

  before do
    enable_doc_auth
    sign_in_and_2fa_user
    complete_doc_auth_steps_before_send_link_step
  end

  let(:idv_send_link_max_attempts) { Figaro.env.idv_send_link_max_attempts.to_i }
  let(:idv_send_link_attempt_window_in_minutes) do
    Figaro.env.idv_send_link_attempt_window_in_minutes.to_i
  end

  it 'is on the correct page' do
    expect(page).to have_current_path(idv_doc_auth_send_link_step)
    expect(page).to have_content(t('doc_auth.headings.take_picture'))
  end

  it 'proceeds to the next page with valid info' do
    expect(Telephony).to receive(:send_doc_auth_link).
      with(hash_including(to: '+1 415-555-0199'))

    fill_in :doc_auth_phone, with: '415-555-0199'
    click_idv_continue

    expect(page).to have_current_path(idv_doc_auth_link_sent_step)
  end

  it 'does not proceed to the next page with invalid info' do
    fill_in :doc_auth_phone, with: ''
    click_idv_continue

    expect(page).to have_current_path(idv_doc_auth_send_link_step)
  end

  it 'does not proceed if Twilio raises a RestError' do
    fill_in :doc_auth_phone, with: '225-555-1000'
    click_idv_continue

    expect(page).to have_current_path(idv_doc_auth_send_link_step)
    expect(page).to have_content I18n.t('telephony.error.friendly_message.generic')
  end

  it 'throttles sending the link' do
    user = sign_in_and_2fa_user
    idv_send_link_max_attempts.times do
      sign_in_and_2fa_user(user)
      complete_doc_auth_steps_before_send_link_step
      expect(page).to_not have_content I18n.t('errors.doc_auth.send_link_throttle')

      fill_in :doc_auth_phone, with: '415-555-0199'
      click_idv_continue

      expect(page).to have_current_path(idv_doc_auth_link_sent_step)
      click_on t('doc_auth.buttons.start_over')
    end

    sign_in_and_2fa_user(user)
    complete_doc_auth_steps_before_send_link_step
    fill_in :doc_auth_phone, with: '415-555-0199'
    click_idv_continue
    expect(page).to have_current_path(idv_doc_auth_send_link_step)
    expect(page).to have_content I18n.t('errors.doc_auth.send_link_throttle')

    Timecop.travel(Time.zone.now + idv_send_link_attempt_window_in_minutes.minutes) do
      fill_in :doc_auth_phone, with: '415-555-0199'
      click_idv_continue
      expect(page).to have_current_path(idv_doc_auth_link_sent_step)
    end
  end
end
