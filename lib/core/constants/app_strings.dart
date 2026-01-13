/// App string constants for consistent text throughout the application
class AppStrings {
  AppStrings._();

  // App Information
  static const String appName = 'Festival Rumour';
  static const String appVersion = '1.0.0';
  static const String appDescription =
      'A Flutter application for festival rumors and events.';

  // Common Actions
  static const String ok = 'OK';
  static const String cancel = 'Cancel';
  static const String confirm = 'Confirm';
  static const String save = 'Save';
  static const String delete = 'Delete';
  static const String edit = 'Edit';
  static const String add = 'Add';
  static const String remove = 'Remove';
  static const String search = 'Search';
  static const String filter = 'Filter';
  static const String sort = 'Sort';
  static const String refresh = 'Refresh';
  static const String retry = 'Retry';
  static const String back = 'Back';
  static const String next = 'Next';
  static const String previous = 'Previous';
  static const String skip = 'Skip for now';
  static const String done = 'Done';
  static const String close = 'Close';
  static const String open = 'Open';
  static const String view = 'View';
  static const String share = 'Share';
  static const String copy = 'Copy';
  static const String paste = 'Paste';
  static const String cut = 'Cut';
  static const String undo = 'Undo';
  static const String redo = 'Redo';

  // Navigation
  static const String home = 'Home';
  static const String profile = 'Profile';
  static const String discover = 'Discover';
  static const String settings = 'Settings';
  static const String about = 'About';
  static const String help = 'Help';
  static const String support = 'Support';
  static const String contact = 'Contact';
  static const String privacy = 'Privacy';
  static const String terms = 'Terms';

  //Button
  // -------------------------
  // 🔹 OTP Validation Strings
  // -------------------------
  static const String invalidOtpError = "Please enter the 4-digit OTP code.";
  static const String otpMismatch =
      "The entered OTP is incorrect. Please try again.";
  static const String resendCodeError =
      "Failed to resend OTP. Please check your connection.";
  static const String nameEmptyError = "Please enter your name.";
  static const String nameTooShortError =
      "Name must be at least 4 characters long.";
  static const String nameInvalidError = "Name can only contain letters.";

  // Authentication
  static const String signIn = 'Sign In';
  static const String signUp = 'Sign Up';
  static const String signOut = 'Sign Out';
  static const String forgotPassword = 'Forgot Password?';
  static const String resetPassword = 'Reset Password';
  static const String changePassword = 'Change Password';
  static const String createAccount = 'Create Account';
  static const String alreadyHaveAccount = 'Already have an account?';
  static const String dontHaveAccount = "Don't have an account? ";
  static const String email = 'Email';
  static const String password = 'Password';
  static const String confirmPassword = 'Confirm Password';
  static const String firstName = 'First Name';
  static const String lastName = 'Last Name';
  static const String phoneNumber = 'Phone Number';
  static const String dateOfBirth = 'Date of Birth';
  static const String enterCode = 'Enter Code';
  static const String resendCode = 'Resend Code';
  static const String verifyCode = 'Verify Code';
  static const String loginWithGoogle = 'Login with Google';
  static const String loginWithEmailPhone = 'Login with Email/Phone';
  static const String loginWithApple = 'Login with Apple';
  static const String signupNow = 'SignUp Now';
  static const String welcomeTitle = 'Welcome to Festival Rumour';
  static const String welcomeSubtitle =
      'Discover and share festival experiences.';
  static const String loginTitle = 'Login to Festival Rumour';
  static const String uploadSubtitle =
      'Upload your recent picture to complete your profile.';
  static const String taponupload = 'Tap to upload image';
  static const String headlineText =
      'Skip the silence, lead me to the  wild alliance';
  static const String phoneHint = '878 7764 2922';
  static const String otpdescription =
      'Please enter your mobile number to sign up. We send you a One-Time Password (OTP) to verify your number.';
  static const String countryPk = 'PK';
  static const String countryUs = 'US';
  static const String localeEnglish = 'en';
  static const String defaultCountryCode = 'PK';
  static const List<String> favoriteCountries = ['+92', 'PK', 'US'];
  static const String primarySettings = "Primary Settings";
  static const String enterOtpDescription =
      "Enter the four digit code we sent to your Number.";
  static const String otpVerificationError =
      "Failed to verify OTP. Please try again.";
  static const String otpResendError =
      "Failed to resend OTP. Please try again.";
  static const String yourFestivalInterests = "Your Festival Interests";
  static const String habitsMatch =
      "Do their habits match yours? You go first.";
  static const String chooseCategories = "Choose from categories";
  static const String lunaFest2025 = "Global Feed";
  static const String proLabel = "PRO";
  static const String selectFestival = "Select Festival";
  static const String loadingPosts = "Loading posts...";
  static const String noPostsAvailable = "No posts available";

  // Forgot Password
  static const String forgotPasswordTitle = 'Forgot Password?';
  static const String forgotPasswordSubtitle =
      'No worries! Enter your email address and we\'ll send you a link to reset your password.';
  static const String enterEmailAddress = 'Enter your email address';
  static const String emailAddressHint = 'Enter your email address';
  static const String sendResetLink = 'Send Reset Link';
  static const String sendingResetLink = 'Sending Reset Link...';
  static const String backToLogin = 'Back to Login';
  static const String resetEmailSent = 'Reset Email Sent';
  static const String resetEmailSentMessage =
      'We\'ve sent a password reset link to your email address. Please check your inbox and follow the instructions to reset your password.';
  static const String didntReceiveEmail = 'Didn\'t receive the email?';
  static const String checkSpamFolder = 'Check your spam folder or try again.';
  static const String resendEmail = 'Resend Email';
  static const String resendingEmail = 'Resending...';
  static const String emailSentSuccessfully = 'Email sent successfully!';
  static const String tryAgainLater = 'Please try again later.';
  static const String emailNotFound =
      'No account found with this email address.';
  static const String invalidEmailFormat =
      'Please enter a valid email address.';
  static const String tooManyRequests =
      'Too many requests. Please try again later.';
  static const String networkError =
      'Network error. Please check your connection.';
  static const String resetPasswordFailed =
      'Failed to send password reset email. Please try again.';
  static const String unexpectedError =
      'An unexpected error occurred. Please try again.';

  static const rememberMe = "Remember me";

  static const login = "Log In";

  // Category names
  static const String culture = "Culture";
  static const String food = "Food";
  static const String music = "Music";
  static const String meetPeople = "Meet People";
  static const String socialsOnWeekends = "Socials on weekends";
  static const String comedy = "Comedy";
  static const String dance = "Dance";
  static const String art = "Art";

  // Error / status messages
  static const String saveInterestsError =
      "Failed to save interests. Please try again.";
  static const String skipInterestsError =
      "Failed to continue. Please try again.";

  static const String failedToLoadPosts = "Failed to load posts";
  static const String postContent =
      "Lorem Ipsum is simply dummy text of the printing industry.";
  static const String timeAgo = "1 hr ago";
  static const String likesnumber = "100";
  static const String commentnumber = "100";
  static const String firstNameQuestion = "What's your first name?";
  static const String firstNameHint = "Enter first name";
  static const String firstNameInfo =
      "This is how it'll appear on your profile.\nCan't change it later.";
  static const String welcomeInfo =
      "There's a lot out there to discover,\nbut let's get your profile set up first.";
  static const String letsGo = "Let's Go";
  static const String editName = "Edit Name";
  static const String saveNameError = "Failed to save name. Please try again.";
  static const String continueError = "Failed to continue. Please try again.";
  static const String nowBadgeText = "NOW";
  static const String overview = "Overview";
  static const String name = "Syed Sheraz ";

  static const String searchHint = "Search festivals...";
  static const String searchFestivals = "Search festivals...";
  static const String more = "more";
  static const String clearSearch = "Clear search";
  static const String allFestivals = "All Festivals";
  static const String live = "Live";
  static const String upcoming = "Upcoming";
  static const String past = "Past";
  static const String toilets = "Toilets";
  static const String news = "News";
  static const String Performance = "Performance";
  static const String event = "Event";
  static const String viewDetail = "View Detail";
  static const String toiletDetail = "Toilet Detail";
  static const String festivalInformation = "Festival Information";
  static const String festivalName = "Festival Name";
  static const String toiletCategory = "Toilet Category";
  static const String image = "Image";
  static const String location = "LOCATION";
  static const String openMap = "Open Map";
  static const String latitude = "Latitude";
  static const String longitude = "Longitude";
  static const String what3word = "What3word";
  static const String bulletin = "Bulletin";
  static const String bulletinPreview = "Bulletin Preview";
  static const String bulletinInformation = "Bulletin Information";
  static const String titleName = "Title Name";
  static const String magicShow = "Magic show";
  static const String content = "Content";
  static const String scheduleOptions = "Schedule Options";
  static const String publishNow = "Publish Now";
  static const String scheduleForLater = "Schedule For Later";
  static const String time = "Time";
  static const String date = "Date";
  static const String shareMessage =
      "Let's enjoy the vibe together 🌙🔥\n\nDownload now: https://festival-romour.link";
  static const String shareSubject = "Join me at LunaFest!";
  static const String shareLocation = "Share Location";
  static const String locationSharingEnabled = "Location Sharing Enabled";
  static const String locationSharingDescription =
      "Allow To Share Location So The Crowd Can Find You, Nothing Else";
  static const String hidingMyVibe = "Hiding My Vibe, Staying Incognito";
  static const String allFilter = "";
  static const String usersFilter = "Users";
  static const String postsFilter = "Posts";
  static const String festivalsFilter = "Festivals";
  static const String loadingfestivals = "Loading festivals...";
  static const String noFestivalsAvailable = "No Festivals available";
  static const String exploreText = "Explore Festivals";
  static const String failedToLoadFestivals = "Failed to load festival";
  static const String commentHint =
      "Ask a question, gather people or share your thoughts";
  // Event titles
  static const String festivalTitle = "Music Fest";
  // Locations
  static const String festivallocation = "Lahore";
  // Dates
  static const String festivaldate = "Oct 28, 2025";

  static const String upgradeToPremium = "Upgrade to Premium";
  // static const String subscribeNow = "Subscribe Now";
  static const String monthlyPlan = "Monthly";
  static const String yearlyPlan = "Yearly";
  static const String lifetimePlan = "Lifetime";

  static const String subscriptionDetails =
      "Subscription Details\n"
      "• Users can join anonymously and remain hidden\n"
      "• Posts and comments will show as 'Anonymous'\n"
      "• Only available to users who purchase this as an in-app premium feature.";

  static const String privacyAgreementText =
      "By continuing you agree with the ";
  static const String privacyPolicy = "Privacy Policy.";

  // Festival Related
  static const String festivals = 'Festivals';
  static const String rumors = 'RUMORS';
  static const String featured = 'Featured';
  static const String popular = 'Popular';

  static const String today = 'Today';
  static const String tomorrow = 'Tomorrow';
  static const String thisWeek = 'This Week';
  static const String thisMonth = 'This Month';

  // Error Messages
  static const String errorOccurred = 'An error occurred';
  // static const String networkError = 'Network error. Please check your connection.';
  static const String serverError = 'Server error. Please try again later.';
  static const String unknownError = 'Unknown error occurred';
  static const String validationError = 'Validation error';
  static const String authenticationError = 'Authentication failed';
  static const String permissionDenied = 'Permission denied';
  static const String fileNotFound = 'File not found';
  static const String invalidInput = 'Invalid input';
  static const String requiredField = 'This field is required';
  static const String invalidEmail = 'Please enter a valid email address';
  static const String invalidPhone = 'Please enter a valid phone number';
  static const String passwordTooShort =
      'Password must be at least 6 characters';
  static const String passwordsDoNotMatch = 'Passwords do not match';
  static const String faildtosignwithmail = 'Failed to sign in with email';
  static const String appleLoginError = 'Failed to sign in with Apple';
  static const String failedtosignwithgoogle = 'Failed to sign in with Google';
  static const String invalidCredentials = 'Invalid credentials';
  static const String failtouploadimage =
      'Failed to pick image from gallery. Please try again.';
  static const String failedtotakephoto =
      'Failed to take photo. Please try again.';
  static const String faildtocontiue = 'Failed to continue. Please try again.';
  static const String contactsPermissionDenied =
      'Contacts permission denied. Please enable contacts access in settings.';
  static const String failedToLoadContacts = 'Failed to load contacts';
  static const String pleaseEnterChatRoomTitle =
      'Please enter a chat room title';
  static const String pleaseSelectAtLeastOneContact =
      'Please select at least one contact';

  // Events Related
  static const String events = 'Events';

  static const String viewAll = 'View All';
  static const String newEventPreview = 'New Event Preview';
  static const String newEventInformation = 'New Event Information';
  static const String title = 'Title';
  static const String abcde = 'Abcde';

  static const String crowdCapacity = 'Crowd Capacity';
  static const String pricePerPerson = 'Price Per Person';
  static const String totalAmount = 'Total Amount';
  static const String tax = 'Tax';
  static const String startTime = 'Start Time';
  static const String endTime = 'End Time';

  // Performance Related
  static const String stageRunningOrder = 'Stage Running Order';
  static const String performance = 'Performance';
  static const String performancePreview = 'Performance Preview';
  static const String performanceInformation = 'Performance Information';
  static const String selectEvent = 'Select Event';
  static const String startDate = 'Start Date';
  static const String endDate = 'End Date';
  static const String performanceTitle = 'Performance Title';
  static const String band = 'Band';
  static const String artist = 'Artist';
  static const String specialGuests = 'Special Guests';
  static const String participantName = 'Atif Aslam';
  static const String notes = 'Notes';

  // News Related
  static const String bulletinManagement = 'Bulletin';
  static const String newBulletin = 'New Bulletin';
  static const String latestFestivalUpdates = 'Latest Festival Updates';

  // Festival Names
  static const String glastonburyFestival = 'Glastonbury Festival';
  static const String musicAndArtsFestival = 'Music and Arts Festival';
  static const String readingAndLeedsFestival = 'Reading And Leeds Festival';
  static const String rockAndAlternativeMusicFestival =
      'Rock and Alternative Music Festival';
  static const String downloadFestival = 'Download Festival';
  static const String rockAndMetalMusicFestival =
      'Rock and Metal Music Festival';

  // Toilet Related

  // Leaderboard Related
  static const String leaderBoard = 'Leader board';
  static const String pro = 'PRO';

  // Subscription Related
  static const String monthly = 'Monthly';
  static const String yearly = 'Yearly';
  static const String lifetime = 'Lifetime';
  static const String postsAndCommentsAnonymous =
      "• Posts and comments will show as 'Anonymous'\n";
  static const String byContinuingYouAgree =
      'By continuing you agree with the ';

  // Username Related
  static const String enterYourEmail = 'Enter your email';
  static const String asterisk = ' *';

  // Mock Contact Names
  static const String robertFox = 'Robert Fox';
  static const String darrellSteward = 'Darrell Steward';
  static const String ronaldRichards = 'Ronald Richards';
  static const String marvinMcKinney = 'Marvin McKinney';
  static const String jeromeBell = 'Jerome Bell';
  static const String kathrynMurphy = 'Kathryn Murphy';
  static const String luna = 'Luna Private Chat Room';
  static const String luna2 = 'Luna Private';

  // Phone Numbers
  static const String phone0123456789 = '0123456789';
  static const String phone0123456790 = '0123456790';
  static const String phone0123456791 = '0123456791';
  static const String phone0123456792 = '0123456792';
  static const String phone0123456887 = '0123456887';
  static const String phone0123456987 = '0123456987';

  // Timestamps
  static const String timestamp2108 = '21:08';
  static const String timestamp2045 = '20:45';
  static const String timestamp0000 = '00:00';
  static const String defaultTime = '12:00';

  // Error Messages
  static const String pageNotFound = 'Page not found';
  static const String joiningRoom = 'Joining room: ';
  static const String invitingFriendsToChatRoom =
      'Inviting friends to chat room';
  static const String sendingMessage = 'Sending message: ';
  static const String invitingToJoinLunaFest =
      'Inviting {contactName} ({phoneNumber}) to join Luna Fest';
  static const String creatingChatRoom = 'Creating chat room: ';
  static const String selectedContacts = 'Selected contacts: ';

  // Discover Screen Strings
  static const String getReady = 'GET READY';
  static const String countMeInCatchYaAtLunaFest =
      'Count me in, catch ya at Luna Fest';
  static const String inviteYourFestieBestie = 'Invite your festie bestie';
  static const String chatRooms = 'CHAT ROOMS';
  static const String detail = 'DETAIL';
  static const String addedToFavorites = '❤️ Added to favorites!';
  static const String removedFromFavorites = '💔 Removed from favorites';

  // Event Header Strings
  static const String saturdayOct11RevelstorkUk =
      'SATURDAY  OCT 11 \nREVELSTORK, UK\n2:00 PM - 2:00';

  // Success Messages
  static const String success = 'Success';
  static const String dataSaved = 'Data saved successfully';
  static const String dataUpdated = 'Data updated successfully';
  static const String dataDeleted = 'Data deleted successfully';
  static const String accountCreated = 'Account created successfully';
  static const String passwordChanged = 'Password changed successfully';
  static const String emailSent = 'Email sent successfully';
  static const String messageSent = 'Message sent successfully';

  // Loading Messages
  static const String loading = 'Loading...';
  static const String pleaseWait = 'Please wait...';
  static const String processing = 'Processing...';
  static const String saving = 'Saving...';
  static const String updating = 'Updating...';
  static const String deleting = 'Deleting...';
  static const String uploading = 'Uploading...';
  static const String downloading = 'Downloading...';
  static const String connecting = 'Connecting...';
  static const String disconnecting = 'Disconnecting...';

  // Empty States
  static const String noData = 'No data available';
  static const String noResults = 'No results found';
  static const String noInternet = 'No internet connection';
  static const String noFestivals = 'No festivals found';
  static const String noEvents = 'No events found';
  static const String noRumors = 'No rumors found';
  static const String noNews = 'No news found';

  // Onboarding
  static const String welcome = 'Welcome';
  static const String FestivalRumour = 'FestivalRumour';
  static const String getStarted = 'Get Started';
  static const String learnMore = 'Learn More';
  static const String continueText = 'Continue';
  static const String finish = 'Finish';

  // Date and Time

  static const String duration = 'Duration';

  // Location
  static const String address = 'Address';
  static const String city = 'City';
  static const String state = 'State';
  static const String country = 'Country';
  static const String zipCode = 'Zip Code';

  // Media
  static const String video = 'Video';
  static const String audio = 'Audio';
  static const String uploadphoto = 'Upload Photos';
  static const String document = 'Document';
  static const String gallery = 'Gallery';
  static const String camera = 'Camera';
  static const String chooseFromGallery = 'Choose from Gallery';
  static const String picupload = 'Add your recent picture';
  static const String recordVideo = 'Record Video';
  static const String selectsourse = 'Select Source';

  // Social
  static const String username = 'Username';
  //static const String followers = 'Followers';
  //  static const String following = 'Following';
  static const String followedFestivals = 'Followed Festivals';
  //static const String settings = 'Settings';
  static const String logout = 'Logout';
  static const String leaderboard = 'Leader board';
  static const String upgradetoprimium = 'Pro \n Upgrade To Premium';
  static const String chat = 'Chat';
  static const String createChatRoom = 'Create Chat Room';
  static const String addTitle = 'Add Title';
  static const String peopleFromContacts =
      'People from your contacts attending Luna Fest.';
  static const String iAmUsingLuna = 'Avaliable';
  static const String invite = 'INVITE';
  static const String privateChats = 'Private Chats';
  static const String post = 'POST';
  static const String createPost = 'Create Post';
  static const String whatsOnYourMind = "What's on your mind?";
  static const String pickImages = 'Pick Images';
  static const String pickVideos = 'Pick Videos';
  static const String uploadPost = 'Upload Post';
  static const String failedToUploadPost =
      'Failed to upload post. Please try again.';
  static const String failedToUploadVideo =
      'Failed to pick video. Please try again.';

  // Chat Room Related
  static const String public = 'Public';
  static const String private = 'Private';
  static const String communityRoom = 'Community room';
  static const String privateRoom = 'Private room';
  static const String lunaFest = 'Luna fest';
  static const String musicFestival = 'Music Festival';
  static const String artCulture = 'Art & Culture';
  static const String foodDrinks = 'Food & Drinks';
  static const String photography = 'Photography';
  static const String lunaCommunityRoom = 'Luna Community Room';
  static const String inviteYourFriends = 'INVITE YOUR FRIENDS';
  static const String typeSomething = 'Type something';
  static const String chatName = 'Chat Name';
  static const String noMessages = 'No messages';
  static const String chatCreated = 'Chat created';
  static const String lunaNews = 'LUNA NEWS';
  static const String chuturCongratulations = 'Chutur congratulations';
  static const String tarunSendMeCssNotes = 'tarun: send me css notes';
  static const String unknown = 'Unknown';
  static const String mobile = 'mobile';

  static const String like = 'Like';
  static const String unlike = 'Unlike';
  static const String comment = 'Comment';
  static const String reply = 'Reply';
  static const String follow = 'Follow';
  static const String unfollow = 'Unfollow';
  static const String followers = 'Followers';
  static const String following = 'Following';
  static const String posts = 'Posts';
  static const String likes = 'Likes';
  static const String comments = 'Comments';
  static const String shares = 'Shares';

  // Settings
  static const String general = 'General';
  static const String notifications = 'Notifications';
  static const String markAllRead = 'Mark All Read';
  static const String noNotifications = 'No notifications yet';
  static const String privacySettings = 'Privacy Settings';
  static const String accountSettings = 'Account Settings';
  static const String language = 'Language';
  static const String theme = 'Theme';
  static const String fontSize = 'Font Size';
  static const String darkMode = 'Dark Mode';
  static const String lightMode = 'Light Mode';
  static const String systemMode = 'System Mode';

  // Validation
  static const String fieldRequired = 'This field is required';
  static const String invalidFormat = 'Invalid format';
  static const String tooShort = 'Too short';
  static const String tooLong = 'Too long';
  static const String mustContain = 'Must contain';
  static const String mustNotContain = 'Must not contain';
  static const String mustMatch = 'Must match';
  static const String mustBeUnique = 'Must be unique';
  static const String mustBeValid = 'Must be valid';
  static const String mustBeNumber = 'Must be a number';
  static const String mustBeEmail = 'Must be a valid email';
  static const String mustBePhone = 'Must be a valid phone number';
  static const String mustBeUrl = 'Must be a valid URL';
  static const String mustBeDate = 'Must be a valid date';
  static const String mustBeTime = 'Must be a valid time';
  static const String emailLabel = "Email";
  static const String emailHint = "Enter your email";
  static const String passwordLabel = "Password";
  static const String passwordHint = "Enter your password";
  static const String confirmPasswordLabel = "Confirm Password";
  static const String confirmPasswordHint = "Enter your confirm password";

  // Additional UI strings
  static const String menu = 'Menu';
  static const String festivalDetail = 'Festival Detail';
  static const String map = 'Map';
  static const String wallet = 'Wallet';
  static const String tickets = 'Tickets';
  static const String subscribeNow = 'Subscribe Now';
  static const String selectFestivalsBy = 'Select Festivals by...';
  static const String monNom = 'MonNom';
  static const String profileDescription = 'La description de mon profil';
  static const String posts100 = '100';
  static const String followers209 = '209';
  static const String following109 = '109';
  static const String festivals3 = '3';

  // Pricing
  static const String price999 = '\$9.99';
  static const String price9999 = '\$99.99';
  static const String price19999 = '\$199.99';

  // Additional hardcoded strings found in UI
  static const String googleLoginDevelopment =
      '🔧 Google login is under development';
  static const String festivalRumourLogo = 'FA';
  static const String festivalRumourTimestamp = 'FestivalRumour 10:05 PM';
  static const String emojiWave = '👋';
  static const String emojiLike = '👍';
  static const String emojiLove = '❤️';
  static const String emojiHaha = '😂';
  static const String emojiWow = '😮';
  static const String emojiSad = '😢';
  static const String emojiAngry = '😡';
  static const String emojiHeart = '❤️';
  static const String emojiThumbsUp = '👍';
  static const String emojiLaughing = '😂';
  static const String emojiSurprised = '😮';
  static const String emojiCrying = '😢';
  static const String emojiAngryFace = '😡';

  // News and Bulletin specific strings

  static const String time200PM = '2.00 PM';
  static const String time1000AM = '10:00 AM';
  static const String date07122024 = '07.12.2024';

  // Leaderboard specific strings

  // Home view specific strings
  static const String jobDetails = 'JOB Details';
  static const String festivalGizzaJob = 'Festival Gizza Job';
  static const String festieHerosJob = 'FestieHeros Job';

  // Job Form Fields
  static const String jobTitle = 'Job Title';
  static const String jobTitleHint = 'e.g., Audio Visual Technician';
  static const String company = 'Company/Organization';
  static const String companyHint = 'e.g., Festival Productions Inc.';
  static const String locationHint = 'e.g., Miami, Florida';
  static const String jobType = 'Job Type';
  static const String salary = 'Salary (Optional)';
  static const String salaryHint = 'e.g., \$25-35/hour or \$50,000/year';
  static const String jobDescription = 'Job Description';
  static const String jobDescriptionHint =
      'Describe the job responsibilities, requirements, and what you\'re looking for...';
  static const String requirements = 'Requirements (Optional)';
  static const String requirementsHint =
      'List any specific skills, experience, or qualifications needed...';
  static const String contactInfo = 'Contact Information';
  static const String contactInfoHint =
      'Email or phone number for applications';
  static const String festivalDate = 'Festival Date';
  static const String festivalDateHint = 'e.g., March 15-17, 2024';

  // Chat specific strings
  static const String festivalRumour = 'FestivalRumour';

  static const String passwordPlaceholder = '********';

  // Profile specific strings
  static const String bioDescription =
      'Bringing people together through music, color, and culture!';

  // Performance & Event Strings

  static const String loremIpsumDummy = '';
  static const String performancetitle = 'Get Ready for the Grand Performance!';
  static const String duaLipa = 'Dua Lipa';

  static const String brand = 'Sony Tseries Apple or Saragama';
  static const String loremIpsumLong =
      'Lorem Ipsum is simply dummy text of the printing and typesetting industry. Lorem Ipsum has been the industry\'s standard dummy text ever since the,';
  static const String festivalPerformanceNote =
      '📝 Important Festival Performance Notes:\n\n'
      '⏰ Gates Open: 5:00 PM\n'
      '🚪 Gates Close: 6:30 PM sharp — no entry will be allowed afterward.\n'
      '🎟️ Please keep your entry pass or QR code ready at the gate.\n'
      '🎶 Performances will begin promptly after gate closure.\n'
      '🚫 No re-entry is allowed once you leave the venue.\n'
      '⚠️ Misbehavior, use of abusive language, or disturbance during the event will lead to immediate removal.\n'
      '📸 Photography and videography may be restricted in certain areas — please follow on-site instructions.\n'
      '🧃 Food and beverages will be available inside; outside items are not permitted.\n'
      '🙏 Enjoy responsibly and help maintain a respectful environment for all attendees.';
  // Performance Category Strings
  static const String liveMusicPerformances = 'Live music performances';
  static const String Atrist = 'Atif Aslam';
  static const String sportsAndGames = 'Sports And Games';
  static const String sportsActivitiesAndGames = 'Sports activities and games';
  static const String exhibitionsAndArtDisplays =
      'Exhibitions And Art Displays';
  static const String artExhibitionsAndDisplays =
      'Art exhibitions and displays';
  static const String culturalPerformances = 'Cultural Performances';
  static const String traditionalCulturalPerformances =
      'Traditional cultural performances';

  // Event category strings
  static const String workshopsAndTalks = 'Workshops & Talks';
  static const String educationalWorkshopsAndSpeakerSessions =
      'Educational workshops and speaker sessions';
  static const String filmScreenings = 'Film Screenings';
  static const String movieAndDocumentaryScreenings =
      'Movie and documentary screenings';
  static const String artInstallations = 'Art Installations';
  static const String interactiveArtDisplaysAndExhibitions =
      'Interactive art displays and exhibitions';
  static const String charityAndCommunityEvents = 'Charity & Community Events';
  static const String communityServiceAndCharityActivities =
      'Community service and charity activities';
  static const String musicPerformances = 'Music Performances';
  static const String liveMusicAndEntertainmentShows =
      'Live music and entertainment shows';

  // Validation strings
  static const String emailRequired = 'Email is required';
  static const String emailInvalid = 'Enter a valid email address';
  static const String passwordRequired = 'Password is required';
  static const String passwordMinLength =
      'Password must be at least 6 characters';
  static const String passwordMaxLength =
      'Password must be less than 50 characters';
  static const String passwordWeak = 'Password is too weak';
  static const String passwordStrong = 'Strong password';
  static const String passwordMedium = 'Medium strength password';
  static const String loginSuccess = 'Login Successful';
  static const String loginFailed = 'Invalid email or password';
  static const String fixErrors = 'Please fix the highlighted errors';
  static const String emailFormat = 'Please enter a valid email format';
  static const String passwordFormat =
      'Password must contain letters and numbers';
  static const String usernameRequired = 'Username is required';
  static const String usernameMinLength =
      'Username must be at least 3 characters';
  static const String usernameMaxLength =
      'Username must be less than 20 characters';
  static const String usernameInvalid =
      'Username can only contain letters, numbers, and underscores';
  static const String usernameAvailable = 'Username is available';
  static const String usernameTaken = 'Username is already taken';
  static const String completeFormToLogin = 'Complete form to login';
  static const String loggingIn = 'Logging in...';

  // Color names for avatar generation
  static const String purple = 'Purple';
  static const String orange = 'Orange';
  static const String grey = 'Grey';
  static const String yellow = 'Yellow';
  static const String blue = 'Blue';
  static const String pink = 'Pink';

  // Reaction labels
  static const String love = 'Love';
  static const String haha = 'Haha';
  static const String wow = 'Wow';
  static const String sad = 'Sad';
  static const String angry = 'Angry';

  // Additional strings found in UI
  static const String searchFollowers = 'Search followers...';
  static const String searchFollowing = 'Search following...';
  static const String editAccountDetails = 'Edit Account Details';
  static const String notification = 'Notification';
  static const String enableOrDisableNotifications =
      'Enable or disable notifications';
  static const String tapToUploadImage = 'Tap to upload image';
  //static const String changePassword = 'Change Password';
  static const String privacySettingsPro = 'Privacy Settings PRO';
  static const String includingAnonymousToggle = 'Including Anonymous toggle';
  static const String badges = 'Badges';
  static const String others = 'Others';
  static const String howToUse = 'How to use ?';
  static const String rateUs = 'Rate Us';
  static const String shareApp = 'Share App';

  static const String termsAndConditions = 'Terms & Conditions';
  static const String postJob = 'POST JOB';

  static const String leaderBoardTitle = 'Leader board';

  static const String selectedFilter = 'Selected Filter';
  static const String userReactedWith = 'User reacted with';

  static const String anonymousFeature1 =
      '• Users can join anonymously and remain hidden';
  static const String anonymousFeature2 =
      '• Posts and comments will show as \'Anonymous\'';
  static const String anonymousFeature3 =
      '• Only available to users who purchase this as an in-app premium feature.';
  static const String joinConversation = 'Join the conversation!';
  static const String followTopicDescription =
      'Follow this topic to receive notifications when people respond.';
  static const String allPosts = 'All Posts';

  // Badge titles and descriptions
  static const String topRumourSpotter = '1  Top Rumour Spotter';
  static const String topRumourSpotterDescription =
      '          For viral or trending posts';
  static const String mediaMaster = '2  Media Master';
  static const String mediaMasterDescription =
      '          For contributing quality photos/videos';
  static const String crowdFavourite = '3  Crowd Favourite';
  static const String crowdFavouriteDescription =
      '          For most liked/reacted content';

  // Danger Zone strings
  static const String dangerZone = 'Danger Zone';
  static const String deleteAccountWarning =
      'Once you delete your account, there is no going back. Please be certain.';
  static const String deleteAccount = 'Delete Account';

  // Mock Data Constants
  static const String mockUserName1 = 'John Doe';
  static const String mockUserName2 = 'Jane Smith';
  static const String mockUserName3 = 'Ali Khan';
  static const String mockUserName4 = 'Mike Johnson';
  static const String mockUserName5 = 'Sarah Wilson';
  static const String mockUserName6 = 'Ayesha Nadeem';
  static const String mockUserName7 = 'LiveStreamer';
  static const String mockUserName8 = 'FestivalGoer';
  static const String mockUserName9 = 'MusicLover';
  static const String mockUserName10 = 'FestivalFan';
  static const String mockUserName11 = 'ConcertGoer';
  static const String mockUserName12 = 'EventPlanner';
  static const String mockUserName13 = 'FestivalVeteran';
  static const String mockUserName14 = 'MusicEnthusiast';
  static const String mockUserName15 = 'ConcertMemories';

  // Mock Bio and Contact Info
  static const String mockBio = 'Music enthusiast and festival lover';
  static const String mockEmail = 'john.doe@example.com';
  static const String mockPhone = '+1 234 567 8900';
  static const String mockWebsite = 'https://johndoe.com';

  // Mock Festival Data
  static const String mockFestival1 = 'Electric Music Festival';
  static const String mockFestival2 = 'Coachella Valley Music Festival';
  static const String mockFestival3 = 'Tomorrowland Electronic Festival';
  static const String mockFestival4 = 'Burning Man Festival';
  static const String mockFestival5 = 'Ultra Music Festival';
  static const String mockFestival6 = 'Glastonbury Festival';

  // Mock Locations
  static const String mockLocation1 = 'Miami, Florida';
  static const String mockLocation2 = 'Indio, California';
  static const String mockLocation3 = 'Boom, Belgium';
  static const String mockLocation4 = 'Black Rock City, Nevada';
  static const String mockLocation5 = 'Pilton, England';

  // Mock Dates
  static const String mockDate1 = 'March 15-17, 2024';
  static const String mockDate2 = 'April 12-14, 2024';
  static const String mockDate3 = 'July 19-21, 2024';
  static const String mockDate4 = 'August 25-September 2, 2024';
  static const String mockDate5 = 'March 22-24, 2024';
  static const String mockDate6 = 'June 26-30, 2024';

  // Validation Error Messages
  static const String bioTooLong = 'Bio must be less than 500 characters';
  static const String websiteInvalidFormat =
      'Website must start with http:// or https://';

  // Firebase Test Messages
  static const String firebaseTest = 'Firebase Test';
  static const String firebaseConnectionTest = 'Firebase Connection Test';
  static const String firebaseAuthTest = 'Firebase Auth Test';
  static const String firebaseWorking = 'Firebase is Working!';
  static const String firebaseIssuesDetected = 'Firebase Issues Detected';
  static const String firebaseWorkingDescription =
      'Your Firebase integration is working correctly. You can use authentication features.';
  static const String firebaseIssuesDescription =
      'There are issues with your Firebase setup. Check the details above.';
  static const String retest = 'Retest';
  static const String goBack = 'Go Back';
  static const String testing = 'Testing...';

  // Apple Login Messages
  static const String appleLoginDevelopment =
      '🍎 Apple login is under development';

  // Comment related strings
  static const String failedToPostComment =
      'Failed to post comment. Please try again.';
}
