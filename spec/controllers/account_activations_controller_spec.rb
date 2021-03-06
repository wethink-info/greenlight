# frozen_string_literal: true

# BigBlueButton open source conferencing system - http://www.bigbluebutton.org/.
#
# Copyright (c) 2018 BigBlueButton Inc. and by respective authors (see below).
#
# This program is free software; you can redistribute it and/or modify it under the
# terms of the GNU Lesser General Public License as published by the Free Software
# Foundation; either version 3.0 of the License, or (at your option) any later
# version.
#
# BigBlueButton is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
# PARTICULAR PURPOSE. See the GNU Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public License along
# with BigBlueButton; if not, see <http://www.gnu.org/licenses/>.

require "rails_helper"

describe AccountActivationsController, type: :controller do
  before { allow(Rails.configuration).to receive(:allow_user_signup).and_return(true) }
  before { allow(Rails.configuration).to receive(:enable_email_verification).and_return(true) }

  describe "GET #show" do
    it "redirects to main room if signed in" do
      user = create(:user, provider: "greenlight")
      @request.session[:user_id] = user.id

      get :show, params: { uid: user.uid }

      expect(response).to redirect_to(user.main_room)
    end

    it "renders the verify view if the user is not signed in and is not verified" do
      user = create(:user, email_verified: false,  provider: "greenlight")
      user.create_activation_token

      get :show, params: { digest: user.activation_digest }

      expect(response).to render_template(:show)
    end
  end

  describe "GET #edit" do
    it "activates a user if they have the correct activation token" do
      @user = create(:user, email_verified: false, provider: "greenlight")

      get :edit, params: { token: @user.create_activation_token }
      @user.reload

      expect(@user.email_verified).to eq(true)
      expect(flash[:success]).to be_present
      expect(response).to redirect_to(signin_path)
    end

    it "should not find user when given fake activation token" do
      @user = create(:user, email_verified: false, provider: "greenlight")

      expect { get :edit, params: { token: "fake_token" } }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "does not allow the user to click the verify link again" do
      @user = create(:user, provider: "greenlight")

      get :edit, params: { token: @user.create_activation_token }
      expect(flash[:alert]).to be_present
      expect(response).to redirect_to(root_path)
    end

    it "redirects a pending user to root with a flash" do
      @user = create(:user, email_verified: false, provider: "greenlight")

      @user.set_role :pending
      @user.reload

      get :edit, params: { token: @user.create_activation_token }

      expect(flash[:success]).to be_present
      expect(response).to redirect_to(root_path)
    end

    context "email mapping" do
      before do
        @role1 = Role.create(name: "role1", priority: 2, provider: "greenlight")
        @role2 = Role.create(name: "role2", priority: 3, provider: "greenlight")
        allow_any_instance_of(Setting).to receive(:get_value).and_return("-123@test.com=role1,@testing.com=role2")
      end

      it "correctly sets users role if email mapping is set" do
        @user = create(:user, email: "test-123@test.com", email_verified: false, provider: "greenlight", role: nil)

        get :edit, params: { token: @user.create_activation_token }

        u = User.last
        expect(u.role).to eq(@role1)
      end

      it "correctly sets users role if email mapping is set (second test)" do
        @user = create(:user, email: "test@testing.com", email_verified: false, provider: "greenlight", role: nil)

        get :edit, params: { token: @user.create_activation_token }

        u = User.last
        expect(u.role).to eq(@role2)
      end

      it "does not replace the role if already set" do
        pending = Role.find_by(name: "pending", provider: "greenlight")
        @user = create(:user, email: "test@testing.com", email_verified: false, provider: "greenlight", role: pending)

        get :edit, params: { token: @user.create_activation_token }

        u = User.last
        expect(u.role).to eq(pending)
      end

      it "defaults to user if no mapping matches" do
        @user = create(:user, email: "test@testing1.com", email_verified: false, provider: "greenlight")

        get :edit, params: { token: @user.create_activation_token }

        u = User.last
        expect(u.role).to eq(Role.find_by(name: "user", provider: "greenlight"))
      end
    end
  end

  describe "GET #resend" do
    it "resends the email to the current user if the resend button is clicked" do
      user = create(:user, email_verified: false, provider: "greenlight")

      expect { get :resend, params: { digest: User.hash_token(user.create_activation_token) } }
        .to change { ActionMailer::Base.deliveries.count }.by(1)
      expect(flash[:success]).to be_present
      expect(response).to redirect_to(root_path)
    end

    it "redirects a verified user to the root path" do
      user = create(:user, provider: "greenlight")

      get :resend, params: { digest: User.hash_token(user.create_activation_token) }

      expect(flash[:alert]).to be_present
      expect(response).to redirect_to(root_path)
    end
  end
end
